namespace payment_identifier;

import std;

// Mod 97-10. A digit adds one decimal place and a letter adds two
// (A is 10 and Z is 35), so the remainder stays below 97 and the value
// never needs a big integer. Returns the checksum (valid when 1), or -1
// for a byte that is not a letter or a digit, or for a long input.
fn mod97_10_checksum(s: const u8[:]) -> i64 {
    if s.len > MAX_ALGO_INPUT { return -1; }
    var r: i64 = 0;
    for i in 0..s.len {
        var c = s[i];
        if c >= 'a' && c <= 'z' { c = c - 32; }
        if is_digit(c) {
            r = (r * 10 + (c - '0')) % 97;
        } else if c >= 'A' && c <= 'Z' {
            r = (r * 100 + (c - 'A') + 10) % 97;
        } else {
            return -1;
        }
    }
    return r;
}

// The check digits that make s valid, as a number 2..98, or -1.
fn mod97_10_value(s: const u8[:]) -> i64 {
    if s.len + 2 > MAX_ALGO_INPUT { return -1; }
    var t: u8[>..] = [];
    t.append(s);
    t.push('0');
    t.push('0');
    let r = mod97_10_checksum(t);
    if r < 0 { return -1; }
    return 98 - r;
}

// Writes the two check digits of s to out. False when s has a bad byte
// or is too long; out stays empty then.
fn mod97_10_digits(out: u8[>..]&, s: const u8[:]) -> bool {
    out.clear();
    let v = mod97_10_value(s);
    if v < 0 { return false; }
    out.push('0' + (v / 10) as u8);
    out.push('0' + (v % 10) as u8);
    return true;
}

fn mod97_10_valid(s: const u8[:]) -> bool {
    return mod97_10_checksum(s) == 1;
}

// Mod 37-2 over an alphabet. Returns the checksum (valid when 1) or -1.
fn mod37_2_checksum(s: const u8[:], alphabet: const u8[:] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ*") -> i64 {
    if s.len > MAX_ALGO_INPUT || alphabet.len < 2 { return -1; }
    let m = alphabet.len;
    var check: i64 = 0;
    for i in 0..s.len {
        let k = alphabet_index(alphabet, s[i]);
        if k < 0 { return -1; }
        check = (2 * check + k) % m;
    }
    return check;
}

// Index in the alphabet of the check digit, or -1.
fn mod37_2_digit(s: const u8[:], alphabet: const u8[:] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ*") -> i64 {
    let c = mod37_2_checksum(s, alphabet);
    if c < 0 { return -1; }
    let m = alphabet.len;
    return (((1 - 2 * c) % m) + m) % m;
}

fn mod37_2_valid(s: const u8[:], alphabet: const u8[:] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ*") -> bool {
    return mod37_2_checksum(s, alphabet) == 1;
}

// Mod 37-36 over an alphabet (any Mod x+1, x).
fn mod37_36_checksum(s: const u8[:], alphabet: const u8[:] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ") -> i64 {
    if s.len > MAX_ALGO_INPUT || alphabet.len < 2 { return -1; }
    let m = alphabet.len;
    var check: i64 = m / 2;
    for i in 0..s.len {
        let k = alphabet_index(alphabet, s[i]);
        if k < 0 { return -1; }
        var c = check;
        if c == 0 { c = m; }
        check = ((c * 2) % (m + 1) + k) % m;
    }
    return check;
}

fn mod37_36_digit(s: const u8[:], alphabet: const u8[:] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ") -> i64 {
    var c = mod37_36_checksum(s, alphabet);
    if c < 0 { return -1; }
    let m = alphabet.len;
    if c == 0 { c = m; }
    return (((1 - (c * 2) % (m + 1)) % m) + m) % m;
}

fn mod37_36_valid(s: const u8[:], alphabet: const u8[:] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ") -> bool {
    return mod37_36_checksum(s, alphabet) == 1;
}

// Mod 11-10 is Mod 37-36 over the digits. Mod 11-2 is Mod 37-2 over
// the digits and X.
fn mod11_10_checksum(s: const u8[:]) -> i64 { return mod37_36_checksum(s, "0123456789"); }
fn mod11_10_digit(s: const u8[:]) -> i64 { return mod37_36_digit(s, "0123456789"); }
fn mod11_10_valid(s: const u8[:]) -> bool { return mod11_10_checksum(s) == 1; }
fn mod11_2_checksum(s: const u8[:]) -> i64 { return mod37_2_checksum(s, "0123456789X"); }
fn mod11_2_digit(s: const u8[:]) -> i64 { return mod37_2_digit(s, "0123456789X"); }
fn mod11_2_valid(s: const u8[:]) -> bool { return mod11_2_checksum(s) == 1; }
