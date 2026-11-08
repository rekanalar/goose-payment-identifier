namespace payment_identifier;

import std;

fn reference_compact(out: u8[>..]&, s: const u8[:]) -> i64 {
    return clean(out, s, MAX_REFERENCE_INPUT, true);
}

fn reference_fault(c: const u8[:]) -> i64 {
    if c.len < 5 || c.len > 25 { return ERR_LENGTH; }
    if c[0] != 'R' || c[1] != 'F' { return ERR_FORMAT; }
    if !is_digit(c[2]) || !is_digit(c[3]) { return ERR_CHECK_DIGITS; }
    let v = (c[2] - '0') * 10 + (c[3] - '0');
    var t: u8[>..] = [];
    t.append(c[4..]);
    t.append(c[..4]);
    if v < 2 || v > 98 || mod97_10_checksum(t) != 1 { return ERR_CHECK_DIGITS; }
    return OK;
}

fn reference_validate(s: const u8[:]) -> i64 {
    var c: u8[>..] = [];
    let f = reference_compact(c, s);
    if f != OK { return f; }
    return reference_fault(c);
}

// Writes the two check digits for a reference body (the part after RF
// and the check digits).
fn reference_check_digits(out: u8[>..]&, body: const u8[:]) -> i64 {
    out.clear();
    var b: u8[>..] = [];
    let f = clean(b, body, MAX_REFERENCE_INPUT, true);
    if f != OK { return f; }
    if b.len > 21 { return ERR_LENGTH; }
    var t: u8[>..] = [];
    t.append(b);
    t.append("RF00");
    let r = mod97_10_checksum(t);
    if r < 0 { return ERR_CHARS; }
    let v = 98 - r;
    out.push('0' + (v / 10) as u8);
    out.push('0' + (v % 10) as u8);
    return OK;
}

// Blocks of four characters, joined by a space.
fn reference_print(out: u8[>..]&, s: const u8[:]) -> i64 {
    var c: u8[>..] = [];
    let f = reference_compact(c, s);
    out.clear();
    if f != OK { return f; }
    for i in 0..c.len {
        if i > 0 && i % 4 == 0 { out.push(' '); }
        out.push(c[i]);
    }
    return OK;
}

// A US ABA routing number: nine digits, and the 3-7-1 check.
fn routing_validate(s: const u8[:]) -> i64 {
    var c: u8[>..] = [];
    let f = clean(c, s, MAX_REFERENCE_INPUT);
    if f != OK { return f; }
    for i in 0..c.len {
        if !is_digit(c[i]) { return ERR_FORMAT; }
    }
    if c.len != 9 { return ERR_LENGTH; }
    let d = c[..9];
    let sum = 7 * ((d[0] - '0') + (d[3] - '0') + (d[6] - '0'))
        + 3 * ((d[1] - '0') + (d[4] - '0') + (d[7] - '0'))
        + 9 * ((d[2] - '0') + (d[5] - '0'));
    if sum % 10 != d[8] - '0' { return ERR_CHECK_DIGITS; }
    return OK;
}
