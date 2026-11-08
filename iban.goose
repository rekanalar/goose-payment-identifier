namespace payment_identifier;

import std;

struct IbanParts {
    country: const u8[:],
    check_digits: const u8[:],
    bban: const u8[:],
    bank: const u8[:],
    branch: const u8[:],
    account: const u8[:],
}

fn registry_version() -> const u8[:] { return "101"; }

fn country_count() -> i64 { return COUNTRIES.len; }

fn country_at(i: i64) -> CountrySpec { return COUNTRIES[i]; }

// Index of a country in the table, or -1. The code needs two letters.
fn country_index(code: const u8[:]) -> i64 {
    if code.len != 2 { return -1; }
    var a = code[0];
    var b = code[1];
    if a >= 'a' && a <= 'z' { a = a - 32; }
    if b >= 'a' && b <= 'z' { b = b - 32; }
    var lo = 0;
    var hi = COUNTRIES.len - 1;
    while lo <= hi {
        let mid = (lo + hi) / 2;
        let c = COUNTRIES[mid].code;
        if c[0] == a && c[1] == b { return mid; }
        if c[0] < a || (c[0] == a && c[1] < b) { lo = mid + 1; } else { hi = mid - 1; }
    }
    return -1;
}

fn country_spec(code: const u8[:]) -> CountrySpec, bool {
    let i = country_index(code);
    if i < 0 { return COUNTRIES[0], false; }
    return COUNTRIES[i], true;
}

fn is_sepa(code: const u8[:]) -> bool {
    let i = country_index(code);
    return i >= 0 && COUNTRIES[i].sepa;
}

fn registry_class_ok(t: u8, c: u8) -> bool {
    if t == 'n' { return is_digit(c); }
    if t == 'a' { return c >= 'A' && c <= 'Z'; }
    return is_digit(c) || (c >= 'A' && c <= 'Z');
}

// True when the BBAN has exactly the shape of the registry structure,
// such as 4!n4!n12!c. The text must be upper case.
fn structure_ok(structure: const u8[:], bban: const u8[:]) -> bool {
    var pos = 0;
    var i = 0;
    while i < structure.len {
        var n = 0;
        while i < structure.len && is_digit(structure[i]) {
            n = n * 10 + (structure[i] - '0');
            i += 1;
        }
        i += 1;
        let t = structure[i];
        i += 1;
        if pos + n > bban.len { return false; }
        for k in 0..n {
            if !registry_class_ok(t, bban[pos + k]) { return false; }
        }
        pos += n;
    }
    return pos == bban.len;
}

fn iban_compact(out: u8[>..]&, s: const u8[:]) -> i64 {
    return clean(out, s, MAX_IBAN_INPUT);
}

// True when the two check digits are numbers from 02 to 98, the only
// values that mod 97-10 can produce. Remainder 1 alone also admits 00, 01
// and 99.
fn iban_digits_ok(c: const u8[:]) -> bool {
    if !is_digit(c[2]) || !is_digit(c[3]) { return false; }
    let v = (c[2] - '0') * 10 + (c[3] - '0');
    return v >= 2 && v <= 98 && iban_remainder(c) == 1;
}

// The mod 97-10 remainder of an IBAN: the first four characters go last.
fn iban_remainder(c: const u8[:]) -> i64 {
    var t: u8[>..] = [];
    t.append(c[4..]);
    t.append(c[..4]);
    return mod97_10_checksum(t);
}

// The first fault of a compact IBAN, in the order country, length,
// structure, check digits.
fn iban_fault(c: const u8[:]) -> i64 {
    if c.len < 4 { return ERR_LENGTH; }
    if !(c[0] >= 'A' && c[0] <= 'Z' && c[1] >= 'A' && c[1] <= 'Z') { return ERR_COUNTRY; }
    let k = country_index(c[..2]);
    if k < 0 { return ERR_COUNTRY; }
    if c.len != COUNTRIES[k].iban_length { return ERR_LENGTH; }
    if !structure_ok(COUNTRIES[k].structure, c[4..]) { return ERR_STRUCTURE; }
    if !iban_digits_ok(c) { return ERR_CHECK_DIGITS; }
    return OK;
}

fn iban_validate(s: const u8[:]) -> i64 {
    var c: u8[>..] = [];
    let f = iban_compact(c, s);
    if f != OK { return f; }
    return iban_fault(c);
}

fn iban_is_valid(s: const u8[:]) -> bool {
    return iban_validate(s) == OK;
}

// Every fault of the text, as validateIBAN of ibantools lists them.
fn iban_faults(faults: i64[>..]&, s: const u8[:]) -> i64 {
    faults.clear();
    var c: u8[>..] = [];
    let f = iban_compact(c, s);
    if f != OK {
        faults.push(f);
        return f;
    }
    if c.len < 4 {
        faults.push(ERR_LENGTH);
        return ERR_LENGTH;
    }
    let k = country_index(c[..2]);
    if k < 0 || !(c[0] >= 'A' && c[0] <= 'Z' && c[1] >= 'A' && c[1] <= 'Z') {
        faults.push(ERR_COUNTRY);
        return ERR_COUNTRY;
    }
    if c.len != COUNTRIES[k].iban_length { faults.push(ERR_LENGTH); }
    if !structure_ok(COUNTRIES[k].structure, c[4..]) { faults.push(ERR_STRUCTURE); }
    if !iban_digits_ok(c) { faults.push(ERR_CHECK_DIGITS); }
    if faults.len == 0 { return OK; }
    return faults[0];
}

// Checks a BBAN of one country against the registry length and structure.
fn bban_validate(country: const u8[:], bban: const u8[:]) -> i64 {
    var b: u8[>..] = [];
    let f = clean(b, bban, MAX_IBAN_INPUT);
    if f != OK { return f; }
    let k = country_index(country);
    if k < 0 { return ERR_COUNTRY; }
    if b.len + 4 != COUNTRIES[k].iban_length { return ERR_LENGTH; }
    if !structure_ok(COUNTRIES[k].structure, b) { return ERR_STRUCTURE; }
    return OK;
}

// Writes the two check digits for a country and a BBAN.
fn iban_check_digits(out: u8[>..]&, country: const u8[:], bban: const u8[:]) -> i64 {
    out.clear();
    let f = bban_validate(country, bban);
    if f != OK { return f; }
    var b: u8[>..] = [];
    clean(b, bban, MAX_IBAN_INPUT);
    var t: u8[>..] = [];
    t.append(b);
    t.append(COUNTRIES[country_index(country)].code);
    t.push('0');
    t.push('0');
    let v = 98 - mod97_10_checksum(t);
    out.push('0' + (v / 10) as u8);
    out.push('0' + (v % 10) as u8);
    return OK;
}

// Writes the whole IBAN for a country and a BBAN.
fn iban_compose(out: u8[>..]&, country: const u8[:], bban: const u8[:]) -> i64 {
    out.clear();
    var d: u8[>..] = [];
    let f = iban_check_digits(d, country, bban);
    if f != OK { return f; }
    var b: u8[>..] = [];
    clean(b, bban, MAX_IBAN_INPUT);
    out.append(COUNTRIES[country_index(country)].code);
    out.append(d);
    out.append(b);
    return OK;
}

fn iban_electronic(out: u8[>..]&, s: const u8[:]) -> i64 {
    return iban_compact(out, s);
}

// Groups of four characters, joined by sep.
fn iban_print(out: u8[>..]&, s: const u8[:], sep: const u8[:]) -> i64 {
    var c: u8[>..] = [];
    let f = iban_compact(c, s);
    out.clear();
    if f != OK { return f; }
    if sep.len > 8 { return ERR_TOO_LONG; }
    for i in 0..c.len {
        if i > 0 && i % 4 == 0 { out.append(sep); }
        out.push(c[i]);
    }
    return OK;
}

// Splits a valid IBAN into its parts. The parts are slices of buf, which
// the caller keeps alive. A part that the country lacks is empty.
fn iban_extract(buf: u8[>..]&, s: const u8[:]) -> IbanParts, i64 {
    let none = IbanParts { country: "", check_digits: "", bban: "", bank: "", branch: "", account: "" };
    let f = iban_compact(buf, s);
    if f != OK { return none, f; }
    let g = iban_fault(buf);
    if g != OK { return none, g; }
    let k = country_index(buf[..2]);
    let sp = COUNTRIES[k];
    let bban = buf[4..];
    let parts = IbanParts {
        country: buf[..2],
        check_digits: buf[2..4],
        bban: bban,
        bank: bban[sp.bank_start..sp.bank_end],
        branch: bban[sp.branch_start..sp.branch_end],
        account: bban[sp.account_start..sp.account_end],
    };
    return parts, OK;
}

// A Swiss or Liechtenstein IBAN whose institution number is 30000 to 31999.
fn is_qr_iban(s: const u8[:]) -> bool {
    var c: u8[>..] = [];
    if iban_compact(c, s) != OK || iban_fault(c) != OK { return false; }
    if !((c[0] == 'C' && c[1] == 'H') || (c[0] == 'L' && c[1] == 'I')) { return false; }
    return c[4] == '3' && (c[5] == '0' || c[5] == '1');
}
