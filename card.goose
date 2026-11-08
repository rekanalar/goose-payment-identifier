namespace payment_identifier;

import std;

// The list of brands. The default value holds the 15 built-in brands in
// the test order of credit-card-type. The order decides the order of a
// partial match.
struct Brands {
    items: Brand[>..<],
}

struct NumberOptions {
    luhn_unionpay: bool,
    skip_luhn: bool,
    max_length: i64,
}

// Result of a number check. It holds no digit of the number.
struct NumberCheck {
    valid: bool,
    potentially_valid: bool,
    brand: i64,
    cause: i64,
}

struct ExpiryCheck {
    valid: bool,
    potentially_valid: bool,
    month: i64,
    year: i64,
}

struct CodeCheck {
    valid: bool,
    potentially_valid: bool,
}

fn number_options() -> NumberOptions {
    return NumberOptions { luhn_unionpay: false, skip_luhn: false, max_length: 0 };
}

fn brands_default() -> Brands {
    var b = Brands { items: [] };
    for i in 0..BUILTIN_BRANDS.len { b.items.push(BUILTIN_BRANDS[i]); }
    return b;
}

fn brands_index(b: Brands&, id: const u8[:]) -> i64 {
    for i in 0..b.items.len {
        if b.items[i].id == id { return i; }
    }
    return -1;
}

// Appends a brand. False when the id is empty or already in the list.
fn brands_add(b: Brands&, brand: Brand) -> bool {
    if brand.id.len == 0 || brands_index(b, brand.id) >= 0 { return false; }
    b.items.push(brand);
    return true;
}

// Replaces the brand with the given id, in place.
fn brands_update(b: Brands&, id: const u8[:], brand: Brand) -> bool {
    let i = brands_index(b, id);
    if i < 0 { return false; }
    b.items[i] = brand;
    return true;
}

fn brands_remove(b: Brands&, id: const u8[:]) -> bool {
    let i = brands_index(b, id);
    if i < 0 { return false; }
    b.items.remove_at(i);
    return true;
}

// Moves the brand to a place in the test order. A place past the end
// puts it last.
fn brands_move(b: Brands&, id: const u8[:], place: i64) -> bool {
    let i = brands_index(b, id);
    if i < 0 || place < 0 { return false; }
    let keep = b.items[i];
    b.items.remove_at(i);
    var p = place;
    if p > b.items.len { p = b.items.len; }
    b.items.insert_at(p, keep);
    return true;
}

fn brands_all(b: Brands&) -> Brand[:] {
    return b.items[..];
}

// A new brand with no pattern, gap or length. Add them with the calls below.
fn brand_new(id: const u8[:], name: const u8[:], code_name: const u8[:], code_size: i64) -> Brand {
    var br = BUILTIN_BRANDS[0];
    br.id = id;
    br.name = name;
    br.code_name = code_name;
    br.code_size = code_size;
    for i in 0..br.patterns.len { br.patterns[i] = 0; }
    for i in 0..br.gaps.len { br.gaps[i] = 0; }
    for i in 0..br.lengths.len { br.lengths[i] = 0; }
    return br;
}

fn digit_count(x: i64) -> i64 {
    var n: i64 = 1;
    var v = x;
    while v >= 10 { v = v / 10; n += 1; }
    return n;
}

fn pow10(n: i64) -> i64 {
    var r: i64 = 1;
    for i in 0..n { r = r * 10; }
    return r;
}

// Adds a prefix pattern. Give low = high for an exact prefix, or two
// bounds of the same length for a range. False when the rows are full or
// the bounds are bad.
fn brand_add_pattern(br: Brand&, low: i64, high: i64) -> bool {
    if low < 0 || high < low || high > 99999999 { return false; }
    for r in 0..br.patterns.len / 3 {
        if br.patterns[r * 3 + 2] == 0 {
            br.patterns[r * 3] = low;
            br.patterns[r * 3 + 1] = high;
            br.patterns[r * 3 + 2] = digit_count(low);
            return true;
        }
    }
    return false;
}

fn brand_add_gap(br: Brand&, gap: i64) -> bool {
    if gap < 1 { return false; }
    for i in 0..br.gaps.len {
        if br.gaps[i] == 0 { br.gaps[i] = gap; return true; }
    }
    return false;
}

fn brand_add_length(br: Brand&, n: i64) -> bool {
    if n < 1 { return false; }
    for i in 0..br.lengths.len {
        if br.lengths[i] == 0 { br.lengths[i] = n; return true; }
    }
    return false;
}

// Cleans a card number: drops spaces and hyphens and keeps digits only.
// This is an internal step. The result stays in the caller's buffer.
fn card_digits(out: u8[>..]&, s: const u8[:]) -> i64 {
    out.clear();
    if s.len > MAX_CARD_INPUT { return ERR_TOO_LONG; }
    for i in 0..s.len {
        let c = s[i];
        if c == ' ' || c == '-' { continue; }
        if !is_digit(c) {
            out.clear();
            return ERR_CHARS;
        }
        out.push(c);
    }
    return OK;
}

// The first n digits of d as a number. n must not pass 18.
fn prefix_val(d: const u8[:], n: i64) -> i64 {
    var v: i64 = 0;
    for i in 0..n { v = v * 10 + (d[i] - '0'); }
    return v;
}

fn row_matches(d: const u8[:], low: i64, high: i64, plen: i64) -> bool {
    var n = plen;
    if d.len < n { n = d.len; }
    let c = prefix_val(d, n);
    let lo = low / pow10(plen - n);
    var hi = high;
    let hlen = digit_count(high);
    if hlen > n { hi = high / pow10(hlen - n); }
    return c >= lo && c <= hi;
}

// Fills hits with the indexes of the brands that still fit the digits, in
// test order. When every hit has a full pattern match, only the best one
// (the longest pattern) stays.
fn card_match_d(hits: i64[>..]&, d: const u8[:], b: Brands&) {
    hits.clear();
    var strength: i64[>..] = [];
    for i in 0..b.items.len {
        for r in 0..b.items[i].patterns.len / 3 {
            let plen = b.items[i].patterns[r * 3 + 2];
            if plen == 0 { break; }
            if plen < 0 || plen > 18 { continue; }
            if row_matches(d, b.items[i].patterns[r * 3], b.items[i].patterns[r * 3 + 1], plen) {
                hits.push(i);
                if d.len >= plen { strength.push(plen); } else { strength.push(0); }
                break;
            }
        }
    }
    var strong = 0;
    for i in 0..strength.len { if strength[i] > 0 { strong += 1; } }
    if strong > 0 && strong == hits.len {
        var best = 0;
        for i in 1..hits.len {
            if strength[best] < strength[i] { best = i; }
        }
        let keep = hits[best];
        hits.clear();
        hits.push(keep);
    }
}

fn card_match(hits: i64[>..]&, digits: const u8[:], b: Brands&) -> i64 {
    hits.clear();
    var d: u8[>..] = [];
    let f = card_digits(d, digits);
    if f != OK { return f; }
    card_match_d(hits, d, b);
    return OK;
}

// The index of the one brand that fits, or -1.
fn card_brand(digits: const u8[:], b: Brands&) -> i64 {
    var hits: i64[>..] = [];
    if card_match(hits, digits, b) != OK || hits.len != 1 { return -1; }
    return hits[0];
}

fn card_verify(digits: const u8[:], b: Brands&, opts: NumberOptions) -> NumberCheck {
    var d: u8[>..] = [];
    let f = card_digits(d, digits);
    if f != OK { return NumberCheck { valid: false, potentially_valid: false, brand: -1, cause: f }; }
    var hits: i64[>..] = [];
    card_match_d(hits, d, b);
    if hits.len == 0 { return NumberCheck { valid: false, potentially_valid: false, brand: -1, cause: ERR_FORMAT }; }
    if hits.len != 1 { return NumberCheck { valid: false, potentially_valid: true, brand: -1, cause: OK }; }
    let k = hits[0];
    let br = b.items[k];
    if opts.max_length > 0 && d.len > opts.max_length {
        return NumberCheck { valid: false, potentially_valid: false, brand: k, cause: ERR_TOO_LONG };
    }
    var luhn_ok = true;
    if !opts.skip_luhn && !(br.id == "unionpay" && !opts.luhn_unionpay) { luhn_ok = luhn_valid(d); }
    var maxlen: i64 = 0;
    for i in 0..br.lengths.len { if br.lengths[i] > maxlen { maxlen = br.lengths[i]; } }
    if opts.max_length > 0 && opts.max_length < maxlen { maxlen = opts.max_length; }
    for i in 0..br.lengths.len {
        if br.lengths[i] == d.len {
            var cause = OK;
            if !luhn_ok { cause = ERR_CHECK_DIGITS; }
            return NumberCheck { valid: luhn_ok, potentially_valid: d.len < maxlen || luhn_ok, brand: k, cause: cause };
        }
    }
    return NumberCheck { valid: false, potentially_valid: d.len < maxlen, brand: k, cause: ERR_LENGTH };
}

fn all_digits(s: const u8[:]) -> bool {
    for i in 0..s.len {
        if !is_digit(s[i]) { return false; }
    }
    return true;
}

fn digits_value(s: const u8[:]) -> i64 {
    var v: i64 = 0;
    for i in 0..s.len { v = v * 10 + (s[i] - '0'); }
    return v;
}

fn code_check(valid: bool, potential: bool) -> CodeCheck {
    return CodeCheck { valid: valid, potentially_valid: potential };
}

// A month: 1 to 12. The text "0" and the empty text could still become one.
fn month_verify(s: const u8[:]) -> CodeCheck {
    if s.len > MAX_DATE_INPUT { return code_check(false, false); }
    var blank = true;
    for i in 0..s.len { if s[i] != ' ' { blank = false; } }
    if blank || s == "0" { return code_check(false, true); }
    if !all_digits(s) { return code_check(false, false); }
    let m = digits_value(s);
    let ok = m > 0 && m < 13;
    return code_check(ok, ok);
}

struct YearCheck {
    valid: bool,
    potentially_valid: bool,
    current: bool,
}

fn year_check(s: const u8[:], year_now: i64, years_ahead: i64) -> YearCheck {
    let no = YearCheck { valid: false, potentially_valid: false, current: false };
    let maybe = YearCheck { valid: false, potentially_valid: true, current: false };
    if s.len > MAX_DATE_INPUT { return no; }
    var blank = true;
    for i in 0..s.len { if s[i] != ' ' { blank = false; } }
    if blank { return maybe; }
    if !all_digits(s) { return no; }
    if s.len < 2 { return maybe; }
    let century = year_now / 100;
    if s.len == 3 {
        return YearCheck { valid: false, potentially_valid: digits_value(s[..2]) == century, current: false };
    }
    if s.len > 4 { return no; }
    let v = digits_value(s);
    let two = year_now % 100;
    var valid = false;
    var current = false;
    if s.len == 2 {
        if v == century { return maybe; }
        current = two == v;
        valid = v >= two && v <= two + years_ahead;
    } else {
        current = year_now == v;
        valid = v >= year_now && v <= year_now + years_ahead;
    }
    return YearCheck { valid: valid, potentially_valid: valid, current: current };
}

// A year of two or four digits. The caller gives the current year.
fn year_verify(s: const u8[:], year_now: i64, years_ahead: i64 = 19) -> CodeCheck {
    let y = year_check(s, year_now, years_ahead);
    return code_check(y.valid, y.potentially_valid);
}

// How many digits of an expiry text without a separator belong to the month.
fn month_digits(s: const u8[:], year_now: i64) -> i64 {
    var first: i64 = -1;
    if s.len > 0 && is_digit(s[0]) { first = s[0] - '0'; }
    if first == 0 { return 2; }
    if first > 1 { return 1; }
    if first == 1 && s.len > 1 && is_digit(s[1]) && s[1] - '0' > 2 { return 1; }
    if first == 1 {
        if year_check(s[1..], year_now, 19).potentially_valid { return 1; }
        return 2;
    }
    if s.len == 5 { return 1; }
    if s.len > 5 { return 2; }
    return 1;
}

// Checks an expiry date such as 12/26, 12 / 2026, 1226, 122026 or 2026-12.
// The caller gives the current year (four digits) and month. The month and
// the year of the result are set only for a valid date.
fn expiry_verify(s: const u8[:], year_now: i64, month_now: i64) -> ExpiryCheck {
    let no = ExpiryCheck { valid: false, potentially_valid: false, month: 0, year: 0 };
    if s.len > MAX_DATE_INPUT { return no; }
    // The month is s[ml..mh] and the year is s[yl..yh].
    var ml = 0;
    var mh = 0;
    var yl = 0;
    var yh = s.len;
    var slash = -1;
    var space = -1;
    for i in 0..s.len {
        if s[i] == '/' && slash < 0 { slash = i; }
        if s[i] == ' ' && space < 0 { space = i; }
    }
    if (s.len == 7 || s.len == 6) && s[4] == '-' && all_digits(s[..4]) && all_digits(s[5..]) {
        ml = 5;
        mh = s.len;
        yl = 0;
        yh = 4;
    } else if slash >= 0 {
        mh = slash;
        while mh > 0 && s[mh - 1] == ' ' { mh -= 1; }
        yl = slash + 1;
        while yl < s.len && s[yl] == ' ' { yl += 1; }
    } else if space >= 0 {
        mh = space;
        yl = space;
        while yl < s.len && s[yl] == ' ' { yl += 1; }
    } else {
        mh = month_digits(s, year_now);
        if mh > s.len { mh = s.len; }
        yl = mh;
    }
    let month = s[ml..mh];
    let year = s[yl..yh];
    let m = month_verify(month);
    let y = year_check(year, year_now, 19);
    if m.valid {
        let mv = digits_value(month);
        var yv = digits_value(year);
        if year.len == 2 { yv = (year_now / 100) * 100 + yv; }
        if y.current {
            let ok = mv >= month_now;
            if ok { return ExpiryCheck { valid: true, potentially_valid: true, month: mv, year: yv }; }
            return no;
        }
        if y.valid { return ExpiryCheck { valid: true, potentially_valid: true, month: mv, year: yv }; }
    }
    if m.potentially_valid && y.potentially_valid {
        return ExpiryCheck { valid: false, potentially_valid: true, month: 0, year: 0 };
    }
    return no;
}

// A security code of the given size: the digits only, nothing else.
fn code_verify(s: const u8[:], size: i64) -> CodeCheck {
    if s.len > MAX_CODE_INPUT || !all_digits(s) { return code_check(false, false); }
    if s.len == size { return code_check(true, true); }
    if s.len < size { return code_check(false, true); }
    var top = size;
    if top < 3 { top = 3; }
    if s.len > top { return code_check(false, false); }
    return code_check(true, true);
}

// True for well-formed UTF-8 without a control character (C0, DEL, C1).
fn name_text_ok(s: const u8[:]) -> bool {
    var i = 0;
    while i < s.len {
        let b = s[i];
        if b < 0x20 || b == 0x7F { return false; }
        if b < 0x80 { i += 1; continue; }
        var n = 0;
        var lo: u8 = 0x80;
        var hi: u8 = 0xBF;
        if b >= 0xC2 && b <= 0xDF { n = 2; }
        else if b >= 0xE0 && b <= 0xEF {
            n = 3;
            if b == 0xE0 { lo = 0xA0; } else if b == 0xED { hi = 0x9F; }
        } else if b >= 0xF0 && b <= 0xF4 {
            n = 4;
            if b == 0xF0 { lo = 0x90; } else if b == 0xF4 { hi = 0x8F; }
        } else { return false; }
        if i + n > s.len { return false; }
        for k in 1..n {
            let c = s[i + k];
            if c < lo || c > hi { return false; }
            lo = 0x80;
            hi = 0xBF;
        }
        if b == 0xC2 && s[i + 1] < 0xA0 { return false; }
        i += n;
    }
    return true;
}

// A cardholder name: 1 to 255 bytes of UTF-8 without a control character.
// A text of only digits, spaces and hyphens is not a name.
fn cardholder_verify(s: const u8[:]) -> CodeCheck {
    if s.len == 0 { return code_check(false, true); }
    if s.len > MAX_NAME_INPUT || !name_text_ok(s) { return code_check(false, false); }
    var number_like = true;
    for i in 0..s.len {
        if !(is_digit(s[i]) || s[i] == ' ' || s[i] == '-') { number_like = false; }
    }
    if number_like { return code_check(false, true); }
    return code_check(true, true);
}

// A postal code: letters and digits in the first min_length characters.
fn postal_verify(s: const u8[:], min_length: i64 = 2) -> CodeCheck {
    var min = min_length;
    if min < 1 { min = 2; }
    if s.len > MAX_POSTAL_INPUT { return code_check(false, false); }
    if s.len < min { return code_check(false, true); }
    var st = 0;
    while st < s.len && s[st] == ' ' { st += 1; }
    var en = s.len;
    while en > st && s[en - 1] == ' ' { en -= 1; }
    let t = s[st..en];
    if t.len < min { return code_check(false, true); }
    for i in 0..min {
        if !is_alnum(t[i]) { return code_check(false, true); }
    }
    return code_check(true, true);
}

// How many digits show at the start and at the end. At least six digits
// stay hidden, and never more than six show at the start or four at the end.
fn mask_counts(n: i64) -> i64, i64 {
    var hidden = n - 10;
    if hidden < 6 { hidden = 6; }
    var reveal = n - hidden;
    if reveal < 0 { reveal = 0; }
    var last = reveal;
    if last > 4 { last = 4; }
    return reveal - last, last;
}

fn card_mask(out: u8[>..]&, digits: const u8[:]) -> i64 {
    out.clear();
    var d: u8[>..] = [];
    let f = card_digits(d, digits);
    if f != OK { return f; }
    if d.len == 0 { return ERR_EMPTY; }
    let first, last = mask_counts(d.len);
    for i in 0..d.len {
        if i < first || i >= d.len - last { out.push(d[i]); } else { out.push('*'); }
    }
    return OK;
}

fn card_last4(out: u8[>..]&, digits: const u8[:]) -> i64 {
    out.clear();
    var d: u8[>..] = [];
    let f = card_digits(d, digits);
    if f != OK { return f; }
    if d.len == 0 { return ERR_EMPTY; }
    let first, last = mask_counts(d.len);
    out.append(d[d.len - last..]);
    return OK;
}

// The masked number with a space at each gap of its brand (groups of four
// when no single brand fits).
fn card_gaps(out: u8[>..]&, digits: const u8[:], b: Brands&) -> i64 {
    var m: u8[>..] = [];
    let f = card_mask(m, digits);
    out.clear();
    if f != OK { return f; }
    let k = card_brand(digits, b);
    for i in 0..m.len {
        var gap = false;
        if k >= 0 {
            for g in 0..b.items[k].gaps.len {
                if b.items[k].gaps[g] == i && i > 0 { gap = true; }
            }
        } else if i > 0 && i % 4 == 0 {
            gap = true;
        }
        if gap { out.push(' '); }
        out.push(m[i]);
    }
    return OK;
}

// Public test numbers from the documentation of the card networks and
// payment processors. No real card has one of them.
const TEST_CARDS: const u8[:][22] = [
    "4111111111111111", "4012888888881881", "4242424242424242", "4000056655665556",
    "5555555555554444", "5105105105105100", "2223000048400011", "2223003122003222",
    "5200828282828210", "378282246310005", "371449635398431", "378734493671000",
    "6011111111111117", "6011000990139424", "30569309025904", "38520000023237",
    "3530111333300000", "3566002020360505", "6200000000000005", "6759649826438453",
    "4000000000000002", "4000000000009995",
];

fn is_test_card(digits: const u8[:]) -> bool {
    var d: u8[>..] = [];
    if card_digits(d, digits) != OK || d.len == 0 { return false; }
    for i in 0..TEST_CARDS.len {
        if TEST_CARDS[i] == d { return true; }
    }
    return false;
}
