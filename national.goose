namespace payment_identifier;

import std;

// National BBAN checks. Each one takes the BBAN of a valid IBAN: the
// length and the structure are right, and the text is upper case.

fn dg(b: const u8[:], i: i64) -> i64 {
    return (b[i] - '0');
}

// Sum of digit * weight over b[start..], one weight per digit.
fn weighted_sum(b: const u8[:], start: i64, weights: const i64[:]) -> i64 {
    var s: i64 = 0;
    for i in 0..weights.len { s += dg(b, start + i) * weights[i]; }
    return s;
}

// The check digit 11 - (sum mod 11), where 10 gives 0 and 11 gives 0.
fn mod11_digit(sum: i64) -> i64 {
    let r = sum % 11;
    if r == 0 { return 0; }
    if r == 1 { return 1; }
    return 11 - r;
}

fn mod10_digit(sum: i64) -> i64 {
    let r = sum % 10;
    if r == 0 { return 0; }
    return 10 - r;
}

const W_CZ_PRE: i64[5] = [10, 5, 8, 4, 2];
const W_CZ_ACC: i64[9] = [6, 3, 7, 9, 10, 5, 8, 4, 2];
const W_ES_BANK: i64[8] = [4, 8, 5, 10, 9, 7, 3, 6];
const W_ES_ACC: i64[10] = [1, 2, 4, 8, 5, 10, 9, 7, 3, 6];
const W_EE: i64[13] = [7, 1, 3, 7, 1, 3, 7, 1, 3, 7, 1, 3, 7];
const W_HU: i64[15] = [9, 7, 3, 1, 9, 7, 3, 1, 9, 7, 3, 1, 9, 7, 3];
const W_NO: i64[10] = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
const W_PL: i64[7] = [3, 9, 7, 1, 3, 9, 7];
const W_IS: i64[8] = [3, 2, 7, 6, 5, 4, 3, 2];
// Odd-position values of the Italian and San Marino check letter.
const IT_ODD: i64[26] = [1, 0, 5, 7, 9, 13, 15, 17, 19, 21, 2, 4, 18, 20, 11, 3, 6, 8, 12, 14, 16, 10, 22, 25, 24, 23];

fn check_be(b: const u8[:]) -> bool {
    var v: i64 = 0;
    for i in 0..b.len - 2 { v = v * 10 + dg(b, i); }
    let r = v % 97;
    var want = r;
    if r == 0 { want = 97; }
    return dg(b, b.len - 2) * 10 + dg(b, b.len - 1) == want;
}

fn check_czsk(b: const u8[:]) -> bool {
    if mod11_digit(weighted_sum(b, 4, W_CZ_PRE)) != dg(b, 9) { return false; }
    return mod11_digit(weighted_sum(b, 10, W_CZ_ACC)) == dg(b, 19);
}

fn check_ee(b: const u8[:]) -> bool {
    return mod10_digit(weighted_sum(b, 2, W_EE)) == dg(b, 15);
}

fn check_es(b: const u8[:]) -> bool {
    if mod11_digit(weighted_sum(b, 0, W_ES_BANK)) != dg(b, 8) { return false; }
    return mod11_digit(weighted_sum(b, 10, W_ES_ACC)) == dg(b, 9);
}

// French and Monegasque RIB: letters become digits (A J 1, B K S 2, ...),
// then the number must be a multiple of 97.
fn check_fr(b: const u8[:]) -> bool {
    var r: i64 = 0;
    for i in 0..b.len {
        var v = (b[i] - '0');
        if b[i] >= 'A' {
            let k = (b[i] - 'A');
            // A-I give 1-9, J-R give 1-9, S-Z give 2-9.
            if k < 9 { v = k + 1; } else if k < 18 { v = k - 8; } else { v = k - 16; }
        }
        r = (r * 10 + v) % 97;
    }
    return r == 0;
}

fn mod11_10_group(b: const u8[:], start: i64, n: i64, control: i64) -> bool {
    var nr: i64 = 10;
    for i in 0..n {
        nr += dg(b, start + i);
        if nr % 10 != 0 { nr = nr % 10; }
        nr = (nr * 2) % 11;
    }
    var want = 11 - nr;
    if want == 10 { want = 0; }
    return control == want;
}

fn check_hr(b: const u8[:]) -> bool {
    return mod11_10_group(b, 0, 6, dg(b, 6)) && mod11_10_group(b, 7, 9, dg(b, 16));
}

fn check_hu(b: const u8[:]) -> bool {
    if mod10_digit(weighted_sum(b, 0, W_HU[..7])) != dg(b, 7) { return false; }
    if b[b.len - 8..] == "00000000" {
        return mod10_digit(weighted_sum(b, 8, W_HU[..7])) == dg(b, 15);
    }
    return mod10_digit(weighted_sum(b, 8, W_HU)) == dg(b, 23);
}

fn check_no(b: const u8[:]) -> bool {
    let r = weighted_sum(b, 0, W_NO) % 11;
    var want = 11 - r;
    if r == 0 { want = 0; }
    return dg(b, 10) == want;
}

fn check_pl(b: const u8[:]) -> bool {
    return mod10_digit(weighted_sum(b, 0, W_PL)) == dg(b, 7);
}

// Bosnia, Montenegro, North Macedonia, Portugal, Serbia and Slovenia:
// the whole BBAN is a multiple of 97 plus 1.
fn check_mod97(b: const u8[:]) -> bool {
    return mod97_10_checksum(b) == 1;
}

fn check_fi(b: const u8[:]) -> bool {
    return luhn_digit(b[..13]) == dg(b, 13);
}

fn check_is(b: const u8[:]) -> bool {
    let id = 12;
    let s = weighted_sum(b, id, W_IS) % 11;
    var want = 11 - s;
    if s == 0 { want = 0; }
    return want < 10 && want == dg(b, id + 8);
}

fn check_it(b: const u8[:]) -> bool {
    var s: i64 = 0;
    for i in 0..22 {
        let c = b[1 + i];
        var v: i64 = 0;
        if c >= 'A' { v = (c - 'A'); } else { v = dg(b, 1 + i); }
        if (i + 1) % 2 == 0 { s += v; } else { s += IT_ODD[v]; }
    }
    return b[0] == 'A' + (s % 26) as u8;
}

// Runs the rule of one country on a clean BBAN of the right shape.
fn national_rule(country: const u8[:], b: const u8[:]) -> i64 {
    var ok = false;
    if country == "BE" { ok = check_be(b); }
    else if country == "CZ" || country == "SK" { ok = check_czsk(b); }
    else if country == "EE" { ok = check_ee(b); }
    else if country == "ES" { ok = check_es(b); }
    else if country == "FR" || country == "MC" { ok = check_fr(b); }
    else if country == "HR" { ok = check_hr(b); }
    else if country == "HU" { ok = check_hu(b); }
    else if country == "NO" { ok = check_no(b); }
    else if country == "PL" { ok = check_pl(b); }
    else if country == "BA" || country == "ME" || country == "MK" || country == "PT" || country == "RS" || country == "SI" { ok = check_mod97(b); }
    else if country == "FI" { ok = check_fi(b); }
    else if country == "IS" { ok = check_is(b); }
    else if country == "IT" || country == "SM" { ok = check_it(b); }
    else { return NATIONAL_NONE; }
    if ok { return NATIONAL_OK; }
    return NATIONAL_BAD;
}

// The national check for a country code and a BBAN. NATIONAL_NONE when
// the country has no rule. NATIONAL_BAD when the BBAN does not have the
// length and structure of the country, so the rule never reads past it.
fn national_check(country: const u8[:], bban: const u8[:]) -> i64 {
    var b: u8[>..] = [];
    if clean(b, bban, MAX_IBAN_INPUT) != OK { return NATIONAL_BAD; }
    let k = country_index(country);
    if k < 0 { return NATIONAL_BAD; }
    if COUNTRIES[k].national == 0 { return NATIONAL_NONE; }
    if b.len + 4 != COUNTRIES[k].iban_length || !structure_ok(COUNTRIES[k].structure, b) { return NATIONAL_BAD; }
    return national_rule(COUNTRIES[k].code, b);
}

// The national result of a whole IBAN. A text that is not a valid IBAN
// gives NATIONAL_BAD, never NATIONAL_OK.
fn iban_validate_national(s: const u8[:]) -> i64 {
    var c: u8[>..] = [];
    if iban_compact(c, s) != OK || iban_fault(c) != OK { return NATIONAL_BAD; }
    return national_check(c[..2], c[4..]);
}

// Like iban_validate, plus a rule of the caller: the block takes the
// country and the BBAN and returns false to reject.
fn iban_validate_with<F: fn(const u8[:], const u8[:]) -> bool>(s: const u8[:]) -> i64 {
    var c: u8[>..] = [];
    var f = iban_compact(c, s);
    if f == OK { f = iban_fault(c); }
    if f != OK { return f; }
    if !F(c[..2], c[4..]) { return ERR_NATIONAL; }
    return OK;
}

fn iban_validate_o(s: const u8[:], opts: IbanOptions) -> i64 {
    var c: u8[>..] = [];
    var f = iban_compact(c, s);
    if f == OK { f = iban_fault(c); }
    if f != OK { return f; }
    if !opts.allow_qr_iban && is_qr_iban(c) { return ERR_QR_IBAN; }
    if opts.national && national_check(c[..2], c[4..]) == NATIONAL_BAD { return ERR_NATIONAL; }
    return OK;
}
