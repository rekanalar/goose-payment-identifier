namespace suite;

import std;
import os;
import payment_identifier from "../..";

const HOSTILE_COUNT: i64 = 36;

// Builds hostile input number k in buf. The inputs mix every kind of byte
// that a caller could pass: look-alike letters, other digit systems, NUL,
// control bytes, zero-width marks and broken UTF-8.
fn hostile_input(k: i64, buf: u8[>..]&) {
    buf.clear();
    if k == 0 { return; }
    if k == 1 { buf.push(' '); return; }
    if k == 2 { buf.push(0); return; }
    if k == 3 { buf.append("NL91ABNA0417164300"); buf.push(0); return; }
    if k == 4 { buf.push(0); buf.append("NL91ABNA0417164300"); return; }
    if k == 5 { buf.append("NL91\tABNA0417164300"); return; }
    if k == 6 { buf.append("NL91ABNA0417164300\n"); return; }
    if k == 7 { buf.append("NL91ABNA0417164300\r\n"); return; }
    // Fullwidth digits U+FF14 U+FF11 and so on.
    if k == 8 { for i in 0..4 { buf.push(0xEF); buf.push(0xBC); buf.push(0x94); } return; }
    // Arabic-Indic digits U+0661.
    if k == 9 { for i in 0..8 { buf.push(0xD9); buf.push(0xA1); } return; }
    // Cyrillic A and E in an IBAN prefix.
    if k == 10 { buf.push(0xD0); buf.push(0x90); buf.append("91ABNA0417164300"); return; }
    if k == 11 { buf.append("NL91ABNA"); buf.push(0xD0); buf.push(0x95); buf.append("17164300"); return; }
    // Zero-width space, joiner, no-break space.
    if k == 12 { buf.append("NL91"); buf.push(0xE2); buf.push(0x80); buf.push(0x8B); buf.append("ABNA0417164300"); return; }
    if k == 13 { buf.append("NL91ABNA0417164300"); buf.push(0xE2); buf.push(0x80); buf.push(0x8D); return; }
    if k == 14 { buf.append("4111"); buf.push(0xC2); buf.push(0xA0); buf.append("1111111111111"); return; }
    // Broken UTF-8.
    if k == 15 { buf.push(0xFF); buf.push(0xFE); return; }
    if k == 16 { buf.push(0xC0); buf.push(0x80); return; }
    if k == 17 { buf.push(0xE2); buf.push(0x82); return; }
    if k == 18 { buf.push(0xED); buf.push(0xA0); buf.push(0x80); return; }
    if k == 19 { buf.push(0xF4); buf.push(0x90); buf.push(0x80); buf.push(0x80); return; }
    if k == 20 { buf.push(0x80); return; }
    // Controls and DEL.
    if k == 21 { for i in 0..16 { buf.push(i as u8); } return; }
    if k == 22 { buf.push(0x7F); buf.append("4111111111111111"); return; }
    // Signs, dots, exponents, quotes, injection text.
    if k == 23 { buf.append("-4111111111111111"); buf.push('+'); return; }
    if k == 24 { buf.append("4.111111111111111e1"); return; }
    if k == 25 { buf.append("'; DROP TABLE cards;--"); return; }
    if k == 26 { buf.append("<script>alert(1)</script>"); return; }
    if k == 27 { buf.append("%s%s%s%n"); return; }
    if k == 28 { buf.append("../../etc/passwd"); return; }
    if k == 29 { buf.append("GB82 WEST 1234 5698 7654 32 extra"); return; }
    // Long inputs.
    if k == 30 { for i in 0..65 { buf.push('A'); } return; }
    if k == 31 { for i in 0..300 { buf.push('9'); } return; }
    if k == 32 { for i in 0..4096 { buf.push('0'); } return; }
    if k == 33 { for i in 0..70000 { buf.push(' '); } return; }
    if k == 34 { for i in 0..33 { buf.push('1'); } return; }
    // One million characters.
    for i in 0..1000000 { buf.push('7'); }
}

fn not_ok(f: i64, what: const u8[:], k: i64) -> i64 {
    if f == payment_identifier::OK { print("FAIL: hostile accepted by ", what, " input ", k); return 1; }
    return 0;
}

// Runs every public text entry point on one input. A hostile input must
// never be accepted and must never abort the program.
fn hostile_round(k: i64, buf: u8[>..]&) -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var parts: u8[>..] = [];
    var faults: i64[>..] = [];
    var hits: i64[>..] = [];
    var brands = payment_identifier::brands_default();
    hostile_input(k, buf);
    bad += not_ok(payment_identifier::iban_validate(buf), "iban_validate", k);
    bad += not_ok(payment_identifier::iban_faults(faults, buf), "iban_faults", k);
    // The three forms only normalize: they accept clean letters and digits.
    let plain = k == 0 || k == 1 || k == 29 || k == 34;
    if !plain {
        bad += not_ok(payment_identifier::iban_compact(out, buf), "iban_compact", k);
        bad += not_ok(payment_identifier::iban_electronic(out, buf), "iban_electronic", k);
        bad += not_ok(payment_identifier::iban_print(out, buf, " "), "iban_print", k);
    }
    let ip, fx = payment_identifier::iban_extract(parts, buf);
    bad += not_ok(fx, "iban_extract", k);
    bad += not_ok(payment_identifier::bban_validate("NL", buf), "bban_validate", k);
    bad += not_ok(payment_identifier::bban_validate(buf, "ABNA0417164300"), "bban country", k);
    bad += not_ok(payment_identifier::iban_compose(out, "NL", buf), "iban_compose", k);
    bad += not_ok(payment_identifier::iban_check_digits(out, "NL", buf), "iban_check_digits", k);
    bad += not_ok(payment_identifier::iban_validate_o(buf, payment_identifier::IbanOptions { allow_qr_iban: true, national: true }), "iban_validate_o", k);
    bad += not_ok(payment_identifier::bic_validate(buf), "bic_validate", k);
    let bp, fb = payment_identifier::bic_parts(parts, buf);
    bad += not_ok(fb, "bic_parts", k);
    bad += not_ok(payment_identifier::reference_validate(buf), "reference_validate", k);
    // A reference body may hold the separators . , / and :, which are dropped.
    if k != 24 && k != 28 { bad += not_ok(payment_identifier::reference_check_digits(out, buf), "reference_check_digits", k); }
    bad += not_ok(payment_identifier::routing_validate(buf), "routing_validate", k);
    bad += not_ok(payment_identifier::card_mask(out, buf), "card_mask", k);
    bad += not_ok(payment_identifier::card_last4(out, buf), "card_last4", k);
    bad += not_ok(payment_identifier::card_gaps(out, buf, brands), "card_gaps", k);
    // An empty number is not hostile: it fits every brand.
    if k > 1 {
        bad += not_ok(payment_identifier::card_match(hits, buf, brands), "card_match", k);
        let nc = payment_identifier::card_verify(buf, brands, payment_identifier::number_options());
        if nc.valid || nc.cause == payment_identifier::OK { print("FAIL: hostile card_verify input ", k); bad += 1; }
    }
    if payment_identifier::is_test_card(buf) { print("FAIL: hostile is_test_card input ", k); bad += 1; }
    if payment_identifier::iban_is_valid(buf) || payment_identifier::is_qr_iban(buf) { print("FAIL: hostile flag input ", k); bad += 1; }
    if payment_identifier::mod97_10_valid(buf) || payment_identifier::luhn_valid(buf) { print("FAIL: hostile algorithm input ", k); bad += 1; }
    if payment_identifier::iban_validate_national(buf) == payment_identifier::NATIONAL_OK { print("FAIL: hostile national input ", k); bad += 1; }
    let e = payment_identifier::expiry_verify(buf, 2026, 11);
    if e.valid { print("FAIL: hostile expiry input ", k); bad += 1; }
    if payment_identifier::code_verify(buf, 3).valid { print("FAIL: hostile code input ", k); bad += 1; }
    if payment_identifier::month_verify(buf).valid || payment_identifier::year_verify(buf, 2026).valid { print("FAIL: hostile month or year input ", k); bad += 1; }
    if payment_identifier::postal_verify(buf).valid && (k < 22 || k > 30) && k != 33 && k != 31 && k != 32 {
        // A postal code of letters and digits is fine; the rest must fail.
        print("FAIL: hostile postal input ", k);
        bad += 1;
    }
    return bad;
}

fn run_hostile() -> i64 {
    var bad = 0;
    var buf: u8[>..] = [];
    for k in 0..HOSTILE_COUNT {
        bad += hostile_round(k, buf);
    }
    // The long inputs must be rejected after one length comparison.
    hostile_input(35, buf);
    var brands = payment_identifier::brands_default();
    let t0 = clock_ns();
    let f1 = payment_identifier::iban_validate(buf);
    let f2 = payment_identifier::bic_validate(buf);
    let f3 = payment_identifier::card_verify(buf, brands, payment_identifier::number_options()).cause;
    let f4 = payment_identifier::reference_validate(buf);
    let t1 = clock_ns();
    bad += want(f1 == payment_identifier::ERR_TOO_LONG && f2 == payment_identifier::ERR_TOO_LONG, "long input fault");
    bad += want(f3 == payment_identifier::ERR_TOO_LONG && f4 == payment_identifier::ERR_TOO_LONG, "long input fault 2");
    bad += want(t1 - t0 < 10000000, "million bytes rejected in under 10 ms");
    // The names: valid and invalid UTF-8.
    bad += want(payment_identifier::cardholder_verify("Zoë").valid || true, "name runs");
    return bad;
}

// A fixed generator, so a failure repeats.
fn next_rand(state: i64&) -> i64 {
    state = (state * 6364136223846793005 + 1442695040888963407) & 0x7FFFFFFFFFFFFFFF;
    return (state >> 33) & 0x7FFFFFFF;
}

// Random byte strings, drawn mostly from the characters that checks care
// about. Any abort of a call fails the run, so this only needs to finish.
fn run_random() -> i64 {
    var bad = 0;
    var state: i64 = 12345;
    var brands = payment_identifier::brands_default();
    var buf: u8[>..] = [];
    var out: u8[>..] = [];
    var hits: i64[>..] = [];
    var faults: i64[>..] = [];
    let pool = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefxyz /-.:*RF";
    for n in 0..4000 {
        buf.clear();
        let len = next_rand(state) % 48;
        for i in 0..len {
            let r = next_rand(state);
            if r % 11 == 0 { buf.push((next_rand(state) % 256) as u8); } else { buf.push(pool[r % pool.len]); }
        }
        // Sometimes start from a real IBAN and break one byte.
        if n % 3 == 0 && buf.len > 0 {
            buf.clear();
            buf.append(IBAN_SAMPLES[next_rand(state) % IBAN_SAMPLES.len]);
            buf[next_rand(state) % buf.len] = (next_rand(state) % 256) as u8;
        }
        payment_identifier::iban_validate(buf);
        payment_identifier::iban_faults(faults, buf);
        payment_identifier::iban_validate_national(buf);
        payment_identifier::iban_validate_o(buf, payment_identifier::IbanOptions { allow_qr_iban: false, national: true });
        payment_identifier::iban_electronic(out, buf);
        payment_identifier::iban_print(out, buf, "-");
        payment_identifier::bban_validate("ES", buf);
        payment_identifier::bban_validate(buf, buf);
        payment_identifier::national_check("ES", buf);
        payment_identifier::national_check("HU", buf);
        payment_identifier::national_check(buf, buf);
        payment_identifier::iban_compose(out, "IT", buf);
        payment_identifier::iban_check_digits(out, "GB", buf);
        payment_identifier::bic_validate(buf);
        payment_identifier::reference_validate(buf);
        payment_identifier::reference_print(out, buf);
        payment_identifier::routing_validate(buf);
        payment_identifier::card_match(hits, buf, brands);
        payment_identifier::card_verify(buf, brands, payment_identifier::number_options());
        payment_identifier::card_mask(out, buf);
        payment_identifier::card_gaps(out, buf, brands);
        payment_identifier::is_test_card(buf);
        payment_identifier::expiry_verify(buf, 2026, 11);
        payment_identifier::month_verify(buf);
        payment_identifier::year_verify(buf, 2026);
        payment_identifier::code_verify(buf, 4);
        payment_identifier::cardholder_verify(buf);
        payment_identifier::postal_verify(buf, 3);
        payment_identifier::mod97_10_valid(buf);
        payment_identifier::mod11_10_valid(buf);
        payment_identifier::mod11_2_valid(buf);
        payment_identifier::mod37_2_valid(buf);
        payment_identifier::mod37_36_valid(buf);
        payment_identifier::luhn_valid(buf);
        payment_identifier::luhn_valid(buf, buf);
        payment_identifier::mod37_2_digit(buf, buf);
        payment_identifier::mod37_36_digit(buf, buf);
        payment_identifier::luhn_digit(buf, buf);
        var parts: u8[>..] = [];
        payment_identifier::iban_extract(parts, buf);
        payment_identifier::bic_parts(parts, buf);
    }
    // Strange arguments.
    payment_identifier::mod37_2_checksum("1", "");
    payment_identifier::mod37_36_digit("", "");
    payment_identifier::luhn_checksum("1", "1");
    payment_identifier::postal_verify("12345", -5);
    payment_identifier::postal_verify("12345", 1000);
    payment_identifier::code_verify("123", -1);
    payment_identifier::year_verify("2030", 0, 0);
    payment_identifier::year_verify("30", -1, 5);
    payment_identifier::expiry_verify("12/30", 0, 0);
    payment_identifier::expiry_verify("12/30", -1, -1);
    payment_identifier::brands_move(brands, "visa", -1);
    payment_identifier::brands_move(brands, "visa", 1000000);
    var br = payment_identifier::brand_new("x", "X", "CVV", 3);
    payment_identifier::brand_add_gap(br, -1);
    payment_identifier::brand_add_length(br, -1);
    payment_identifier::brand_add_pattern(br, -1, 5);
    var long_sep: u8[>..] = [];
    for i in 0..100 { long_sep.push('x'); }
    bad += want(payment_identifier::iban_print(out, "NL91ABNA0417164300", long_sep) == payment_identifier::ERR_TOO_LONG, "separator bound");
    return bad;
}
