namespace suite;

import std;
import payment_identifier from "../..";

fn reject_xx(country: const u8[:], bban: const u8[:]) -> bool {
    return country != "NL";
}

fn run_national() -> i64 {
    var bad = 0;
    var covered = 0;
    var none = 0;
    for i in 0..IBAN_SAMPLES.len {
        let s = IBAN_SAMPLES[i];
        let r = payment_identifier::national_check(s[..2], s[4..]);
        var expect_bad = false;
        for j in 0..NATIONAL_BAD_SAMPLES.len {
            if NATIONAL_BAD_SAMPLES[j] == s { expect_bad = true; }
        }
        // The model of the generator knows which samples fail the national rule.
        if expect_bad != (r == payment_identifier::NATIONAL_BAD) { bad += fail("national sample", s); }
        if r == payment_identifier::NATIONAL_OK { covered += 1; }
        if r == payment_identifier::NATIONAL_NONE { none += 1; }
    }
    bad += want(covered > 100 && none > 50, "national coverage");
    // Per country: a good sample passes and changing digits makes at least
    // one variant fail.
    var countries: u8[>..] = [];
    countries.append("BA BE CZ SK EE ES FR MC HR HU ME MK NO PL PT RS SI FI IS IT SM ");
    var k = 0;
    var seen = 0;
    while k + 2 <= countries.len {
        let cc = countries[k..k + 2];
        var any_sample = false;
        var any_fail = false;
        for i in 0..IBAN_SAMPLES.len {
            let s = IBAN_SAMPLES[i];
            if s[..2] != cc { continue; }
            any_sample = true;
            var m: u8[>..] = [];
            m.append(s[4..]);
            var j = 0;
            while j < m.len {
                if m[j] >= '0' && m[j] <= '9' {
                    let old = m[j];
                    m[j] = '0' + ((m[j] - '0') + 1) % 10;
                    if payment_identifier::bban_validate(cc, m) == payment_identifier::OK
                        && payment_identifier::national_check(cc, m) == payment_identifier::NATIONAL_BAD {
                        any_fail = true;
                    }
                    m[j] = old;
                }
                j += 1;
            }
        }
        if !any_sample || !any_fail { bad += fail("national country", cc); }
        seen += 1;
        k += 3;
    }
    bad += want(seen == 21, "21 national countries");
    // A country with no rule.
    bad += want(payment_identifier::iban_validate_national("NL91ABNA0417164300") == payment_identifier::NATIONAL_NONE, "NL has none");
    bad += want(payment_identifier::iban_validate_national("DE89370400440532013000") == payment_identifier::NATIONAL_NONE, "DE has none");
    bad += want(payment_identifier::iban_validate_national("ES9121000418450200051332") == payment_identifier::NATIONAL_OK, "ES ok");
    bad += want(payment_identifier::iban_validate_national("not an iban") == payment_identifier::NATIONAL_BAD, "bad text");
    // Spanish account digit changed, IBAN check digits recomputed.
    var out: u8[>..] = [];
    bad += want(payment_identifier::iban_compose(out, "ES", "21000418450200051331") == payment_identifier::OK, "compose es");
    bad += want(payment_identifier::iban_validate(out) == payment_identifier::OK, "es iban valid");
    bad += want(payment_identifier::iban_validate_national(out) == payment_identifier::NATIONAL_BAD, "es national bad");
    bad += want(payment_identifier::iban_validate_o(out, payment_identifier::IbanOptions { allow_qr_iban: true, national: true }) == payment_identifier::ERR_NATIONAL, "options national");
    bad += want(payment_identifier::iban_validate_o(out, payment_identifier::IbanOptions { allow_qr_iban: true, national: false }) == payment_identifier::OK, "options off");
    bad += want(payment_identifier::iban_validate_o("CH4431999123000889012", payment_identifier::IbanOptions { allow_qr_iban: false, national: false }) == payment_identifier::ERR_QR_IBAN, "qr refused");
    bad += want(payment_identifier::iban_validate_o("CH4431999123000889012", payment_identifier::IbanOptions { allow_qr_iban: true, national: false }) == payment_identifier::OK, "qr allowed");
    // The block of the caller.
    bad += want(payment_identifier::iban_validate_with("NL91ABNA0417164300") { c, b => reject_xx(c, b) } == payment_identifier::ERR_NATIONAL, "block rejects");
    bad += want(payment_identifier::iban_validate_with("DE89370400440532013000") { c, b => reject_xx(c, b) } == payment_identifier::OK, "block accepts");
    // BBAN checks.
    bad += want(payment_identifier::bban_validate("NL", "ABNA0417164300") == payment_identifier::OK, "bban ok");
    bad += want(payment_identifier::bban_validate("DE", "3704004405320130") == payment_identifier::ERR_LENGTH, "bban short");
    bad += want(payment_identifier::bban_validate("DE", "37040044053201300X") == payment_identifier::ERR_STRUCTURE, "bban structure");
    bad += want(payment_identifier::bban_validate("XX", "1234") == payment_identifier::ERR_COUNTRY, "bban country");
    bad += want(payment_identifier::bban_validate("GB", "NWBK60161331926819") == payment_identifier::OK, "bban gb");
    return bad;
}
