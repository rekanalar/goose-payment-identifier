namespace payment_identifier;

import std;

// Luhn checksum over an alphabet (Luhn mod N). Valid when 0. Returns -1
// for a byte outside the alphabet or for a long input.
fn luhn_checksum(s: const u8[:], alphabet: const u8[:] = "0123456789") -> i64 {
    if s.len > MAX_ALGO_INPUT || alphabet.len < 2 { return -1; }
    let n = alphabet.len;
    var sum: i64 = 0;
    var dbl = false;
    var i = s.len;
    while i > 0 {
        i -= 1;
        var k = alphabet_index(alphabet, s[i]);
        if k < 0 { return -1; }
        if dbl {
            k = k * 2;
            k = k / n + k % n;
        }
        sum += k;
        dbl = !dbl;
    }
    return sum % n;
}

// Index in the alphabet of the digit that makes s valid, or -1.
fn luhn_digit(s: const u8[:], alphabet: const u8[:] = "0123456789") -> i64 {
    if s.len + 1 > MAX_ALGO_INPUT || alphabet.len < 2 { return -1; }
    var t: u8[>..] = [];
    t.append(s);
    t.push(alphabet[0]);
    let c = luhn_checksum(t, alphabet);
    if c < 0 { return -1; }
    return (alphabet.len - c) % alphabet.len;
}

fn luhn_valid(s: const u8[:], alphabet: const u8[:] = "0123456789") -> bool {
    return s.len > 0 && luhn_checksum(s, alphabet) == 0;
}
