namespace suite;

import std;
import payment_identifier from "../..";

fn fail(what: const u8[:], s: const u8[:]) -> i64 {
    print("FAIL: ", what, " ", s);
    return 1;
}

fn run_iban() -> i64 {
    var bad = 0;
    // Every sample passes. One changed digit fails with a check digit fault.
    for i in 0..IBAN_SAMPLES.len {
        let s = IBAN_SAMPLES[i];
        if payment_identifier::iban_validate(s) != payment_identifier::OK { bad += fail("sample", s); }
        var m: u8[>..] = [];
        m.append(s);
        let last = m.len - 1;
        // Change a digit in the BBAN tail only when it keeps the structure.
        var found = false;
        var j = last;
        while j >= 4 && !found {
            if m[j] >= '0' && m[j] <= '8' {
                m[j] = m[j] + 1;
                found = true;
            } else {
                j -= 1;
            }
        }
        if found {
            let f = payment_identifier::iban_validate(m);
            if f != payment_identifier::ERR_CHECK_DIGITS && f != payment_identifier::ERR_STRUCTURE {
                bad += fail("changed digit", m);
            }
            if f == payment_identifier::OK { bad += fail("changed digit accepted", m); }
        }
    }
    bad += run_iban_build();
    return bad;
}

fn eq(got: const u8[:], want: const u8[:], what: const u8[:]) -> i64 {
    if got != want { print("FAIL: ", what, " got ", got, " want ", want); return 1; }
    return 0;
}

fn want(ok: bool, what: const u8[:]) -> i64 {
    if !ok { print("FAIL: ", what); return 1; }
    return 0;
}

fn run_iban_build() -> i64 {
    var bad = 0;
    let pi = payment_identifier::OK;
    // Faults.
    bad += want(payment_identifier::iban_validate("XX431234") == payment_identifier::ERR_COUNTRY, "unknown country");
    bad += want(payment_identifier::iban_validate("0001") == payment_identifier::ERR_COUNTRY, "digits first");
    bad += want(payment_identifier::iban_validate("NL91ABNA041716430") == payment_identifier::ERR_LENGTH, "short");
    bad += want(payment_identifier::iban_validate("NL91ABNA0417164301") == payment_identifier::ERR_CHECK_DIGITS, "bad digits");
    bad += want(payment_identifier::iban_validate("NL91ABNA04171643AB") == payment_identifier::ERR_STRUCTURE, "letters in account");
    bad += want(payment_identifier::iban_validate("") == payment_identifier::ERR_EMPTY, "empty");
    bad += want(payment_identifier::iban_validate("NL91*ABNA0417164300") == payment_identifier::ERR_CHARS, "star");
    bad += want(payment_identifier::iban_validate("nl91 abna-0417 1643 00") == pi, "lower case, spaces and hyphen");
    bad += want(payment_identifier::iban_validate("GB00HLFX11016111455365") == payment_identifier::ERR_CHECK_DIGITS, "check digits 00");
    var faults: i64[>..] = [];
    payment_identifier::iban_faults(faults, "NL91ABNA041716430X");
    bad += want(faults.len == 2 && faults[0] == payment_identifier::ERR_STRUCTURE, "faults list");
    // Compose, forms.
    var out: u8[>..] = [];
    bad += want(payment_identifier::iban_compose(out, "NL", "ABNA0417164300") == pi, "compose ok");
    bad += eq(out, "NL91ABNA0417164300", "compose");
    bad += want(payment_identifier::iban_check_digits(out, "NL", "ABNA0417164300") == pi, "check digits ok");
    bad += eq(out, "91", "check digits");
    bad += want(payment_identifier::iban_compose(out, "NL", "ABNA04171643") == payment_identifier::ERR_LENGTH, "compose short");
    bad += want(payment_identifier::iban_compose(out, "NL", "1234041716430X") == payment_identifier::ERR_STRUCTURE, "compose structure");
    bad += want(payment_identifier::iban_compose(out, "XX", "1234") == payment_identifier::ERR_COUNTRY, "compose country");
    payment_identifier::iban_print(out, "NL91ABNA0417164300", " ");
    bad += eq(out, "NL91 ABNA 0417 1643 00", "print");
    payment_identifier::iban_print(out, "nl91abna0417164300", "-");
    bad += eq(out, "NL91-ABNA-0417-1643-00", "print separator");
    payment_identifier::iban_electronic(out, "NL91 ABNA 0417 1643 00");
    bad += eq(out, "NL91ABNA0417164300", "electronic");
    for i in 0..IBAN_SAMPLES.len {
        let s = IBAN_SAMPLES[i];
        if payment_identifier::iban_compose(out, s[..2], s[4..]) != pi || out != s {
            bad += eq(out, s, "compose from sample");
        }
    }
    // Parts.
    var buf: u8[>..] = [];
    let p, f = payment_identifier::iban_extract(buf, "DE89 3704 0044 0532 0130 00");
    bad += want(f == pi, "extract ok");
    bad += eq(p.country, "DE", "country");
    bad += eq(p.check_digits, "89", "check");
    bad += eq(p.bank, "37040044", "bank");
    bad += eq(p.account, "0532013000", "account");
    bad += eq(p.branch, "", "branch");
    // SEPA and QR-IBAN.
    var sepa = 0;
    for i in 0..payment_identifier::country_count() {
        if payment_identifier::country_at(i).sepa { sepa += 1; }
    }
    bad += want(sepa == 37 && payment_identifier::country_count() == 89, "37 SEPA of 89");
    bad += want(payment_identifier::is_sepa("NL") && !payment_identifier::is_sepa("PK"), "is_sepa");
    bad += want(payment_identifier::is_qr_iban("CH4431999123000889012"), "qr iban");
    bad += want(!payment_identifier::is_qr_iban("CH9300762011623852957"), "not qr iban");
    bad += want(!payment_identifier::is_qr_iban("DE89370400440532013000"), "de is not qr");
    bad += eq(payment_identifier::registry_version(), "101", "registry version");
    return bad;
}

// The one-line checks of ibantools. For a country outside the registry
// ibantools may say true, and this package says false.
fn run_ibantools() -> i64 {
    var bad = 0;
    // isValidIBAN of ibantools also runs the national check, so the call here
    // sets that option. ibantools wants the electronic form, and it rejects
    // spaces and hyphens. This package drops them first, so those cases are
    // skipped.
    let opts = payment_identifier::IbanOptions { allow_qr_iban: true, national: true };
    for i in 0..TOOLS_IBANS.len {
        let c = TOOLS_IBANS[i];
        var spaced = false;
        for k in 0..c.s.len { if c.s[k] == ' ' || c.s[k] == '-' { spaced = true; } }
        if spaced { continue; }
        var want_valid = c.valid;
        if !c.in_registry { want_valid = false; }
        // ibantools has no rule for FI, IS, IT and SM. schwifty has one, and the
        // sample FI6879826661004681 fails it. The two references disagree, so
        // those countries are checked without the national rule here.
        var o = opts;
        if c.s[..2] == "FI" || c.s[..2] == "IS" || c.s[..2] == "IT" || c.s[..2] == "SM" { o.national = false; }
        if (payment_identifier::iban_validate_o(c.s, o) == payment_identifier::OK) != want_valid { print("FAIL: ibantools iban [", c.s, "] want ", want_valid); bad += 1; }
    }
    for i in 0..TOOLS_BICS.len {
        let c = TOOLS_BICS[i];
        if (payment_identifier::bic_validate(c.s) == payment_identifier::OK) != c.valid { print("FAIL: ibantools bic [", c.s, "] want ", c.valid); bad += 1; }
    }
    for i in 0..TOOLS_SEPA.len {
        let c = TOOLS_SEPA[i];
        if payment_identifier::is_sepa(c.s) != c.valid { print("FAIL: ibantools sepa [", c.s, "]"); bad += 1; }
    }
    return bad;
}
