namespace payment_identifier;

import std;

// True when the byte is an ASCII letter or digit.
fn is_alnum(c: u8) -> bool {
    return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
}

fn is_digit(c: u8) -> bool {
    return c >= '0' && c <= '9';
}

// The bound check. It runs before any other work, so a huge input costs
// one comparison.
fn check_bound(s: const u8[:], limit: i64) -> i64 {
    if s.len == 0 { return ERR_EMPTY; }
    if s.len > limit { return ERR_TOO_LONG; }
    return OK;
}

// Copies s into out without spaces and hyphens, and upper-cases ASCII
// letters. Every other byte, such as NUL, a control byte, a byte above
// 127 or a zero-width mark, gives ERR_CHARS. out is cleared first.
// With dots set it also drops . , / and :, the separators of a creditor
// reference.
fn clean(out: u8[>..]&, s: const u8[:], limit: i64, dots: bool = false) -> i64 {
    out.clear();
    let bound = check_bound(s, limit);
    if bound != OK { return bound; }
    for i in 0..s.len {
        let c = s[i];
        if c == ' ' || c == '-' { continue; }
        if dots && (c == '.' || c == ',' || c == '/' || c == ':') { continue; }
        if c >= 'a' && c <= 'z' {
            out.push(c - 32);
        } else if is_alnum(c) {
            out.push(c);
        } else {
            out.clear();
            return ERR_CHARS;
        }
    }
    if out.len == 0 { return ERR_EMPTY; }
    return OK;
}

// Position of byte c in the alphabet, or -1.
fn alphabet_index(alphabet: const u8[:], c: u8) -> i64 {
    for i in 0..alphabet.len {
        if alphabet[i] == c { return i; }
    }
    return -1;
}
