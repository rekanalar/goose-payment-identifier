namespace suite;

import std;
import payment_identifier from "../..";

fn digit_total(s: const u8[:]) -> i64 {
    var n: i64 = 0;
    for i in 0..s.len { if s[i] >= '0' && s[i] <= '9' { n += 1; } }
    return n;
}

fn run_mask() -> i64 {
    var bad = 0;
    var b = payment_identifier::brands_default();
    var out: u8[>..] = [];
    // No text output of any card number shows more than ten digits.
    for i in 0..NUM_CASES.len {
        let f = payment_identifier::card_mask(out, NUM_CASES[i].s);
        if f == payment_identifier::OK && digit_total(out) > 10 { print("FAIL: mask shows too much [", out, "]"); bad += 1; }
        let f2 = payment_identifier::card_gaps(out, NUM_CASES[i].s, b);
        if f2 == payment_identifier::OK && digit_total(out) > 10 { print("FAIL: gaps show too much [", out, "]"); bad += 1; }
        let f3 = payment_identifier::card_last4(out, NUM_CASES[i].s);
        if f3 == payment_identifier::OK && digit_total(out) > 4 { print("FAIL: last four show too much [", out, "]"); bad += 1; }
    }
    payment_identifier::card_mask(out, "4111 1111 1111 1111");
    bad += eq(out, "411111******1111", "mask 16");
    payment_identifier::card_mask(out, "378282246310005");
    bad += eq(out, "37828******0005", "mask 15");
    payment_identifier::card_mask(out, "1234");
    bad += eq(out, "****", "mask 4");
    payment_identifier::card_mask(out, "12345678");
    bad += eq(out, "******78", "mask 8");
    payment_identifier::card_mask(out, "6200000000000005123");
    bad += eq(out, "620000*********5123", "mask 19");
    payment_identifier::card_last4(out, "4111111111111111");
    bad += eq(out, "1111", "last four");
    payment_identifier::card_last4(out, "123");
    bad += eq(out, "", "last four short");
    payment_identifier::card_gaps(out, "4111111111111111", b);
    bad += eq(out, "4111 11** **** 1111", "gaps visa");
    payment_identifier::card_gaps(out, "378282246310005", b);
    bad += eq(out, "3782 8***** *0005", "gaps amex");
    payment_identifier::card_gaps(out, "9", b);
    bad += eq(out, "*", "gaps one brand");
    bad += want(payment_identifier::card_mask(out, "") == payment_identifier::ERR_EMPTY, "mask empty");
    bad += want(payment_identifier::card_mask(out, "41x1") == payment_identifier::ERR_CHARS, "mask letters");
    // Test numbers.
    bad += want(payment_identifier::is_test_card("4111 1111 1111 1111"), "test card visa");
    bad += want(payment_identifier::is_test_card("378282246310005"), "test card amex");
    bad += want(!payment_identifier::is_test_card("4111111111111112"), "not a test card");
    bad += want(!payment_identifier::is_test_card(""), "empty not a test card");
    for i in 0..payment_identifier::TEST_CARDS.len {
        let r = payment_identifier::card_verify(payment_identifier::TEST_CARDS[i], b, payment_identifier::number_options());
        if !r.valid { print("FAIL: test card is not valid [", i, "]"); bad += 1; }
    }
    return bad;
}

fn run_brands() -> i64 {
    var bad = 0;
    var b = payment_identifier::brands_default();
    var hits: i64[>..] = [];
    bad += want(payment_identifier::brands_all(b).len == 15, "15 brands");
    // Every brand: its own test number gives that brand.
    bad += want(payment_identifier::card_brand("4111111111111111", b) == 0, "visa index");
    bad += want(payment_identifier::card_brand("5555555555554444", b) == 1, "mastercard index");
    bad += want(payment_identifier::card_brand("378282246310005", b) == 2, "amex index");
    bad += want(payment_identifier::card_brand("30569309025904", b) == 3, "diners index");
    bad += want(payment_identifier::card_brand("6011111111111117", b) == 4, "discover index");
    bad += want(payment_identifier::card_brand("3530111333300000", b) == 6, "jcb index");
    bad += want(payment_identifier::card_brand("6200000000000005", b) == 7, "unionpay index");
    bad += want(payment_identifier::card_brand("2200000000000000", b) == 12, "mir index");
    bad += want(payment_identifier::card_brand("6062826786276634", b) == 14, "hipercard index");
    bad += want(payment_identifier::card_brand("6370950000000005", b) == 13, "hiper index");
    bad += want(payment_identifier::card_brand("4", b) == -1, "one digit is not enough");
    // Edit the list.
    bad += want(payment_identifier::brands_remove(b, "visa"), "remove visa");
    bad += want(!payment_identifier::brands_remove(b, "visa"), "remove twice");
    bad += want(payment_identifier::brands_all(b).len == 14, "14 brands");
    bad += want(payment_identifier::card_brand("4111111111111111", b) != 0, "visa is gone");
    var br = payment_identifier::brand_new("acme", "Acme", "CVV", 3);
    bad += want(payment_identifier::brand_add_pattern(br, 9001, 9001), "pattern");
    bad += want(payment_identifier::brand_add_pattern(br, 9100, 9199), "range");
    bad += want(!payment_identifier::brand_add_pattern(br, 5, 4), "bad range");
    bad += want(!payment_identifier::brand_add_pattern(br, 1, 100000000), "pattern too long");
    bad += want(payment_identifier::brand_add_gap(br, 4), "gap");
    bad += want(payment_identifier::brand_add_length(br, 16), "length");
    bad += want(payment_identifier::brands_add(b, br), "add acme");
    bad += want(!payment_identifier::brands_add(b, br), "add acme twice");
    payment_identifier::card_match(hits, "9001", b);
    bad += want(hits.len == 1 && payment_identifier::brands_all(b)[hits[0]].id == "acme", "acme matches");
    payment_identifier::card_match(hits, "9150", b);
    bad += want(hits.len == 1 && payment_identifier::brands_all(b)[hits[0]].id == "acme", "acme range");
    bad += want(payment_identifier::brands_move(b, "acme", 0), "move acme");
    bad += want(payment_identifier::brands_all(b)[0].id == "acme", "acme first");
    bad += want(!payment_identifier::brands_move(b, "nope", 0), "move unknown");
    var br2 = payment_identifier::brand_new("acme", "Acme Two", "CVC", 4);
    bad += want(payment_identifier::brands_update(b, "acme", br2), "update acme");
    bad += want(payment_identifier::brands_all(b)[0].name == "Acme Two", "acme updated");
    // A bank-issued card of 19 digits passes with the brand limit.
    var d = payment_identifier::brands_default();
    var opt = payment_identifier::number_options();
    opt.max_length = 16;
    bad += want(!payment_identifier::card_verify("4111111111111111111", d, opt).valid, "max length");
    opt.max_length = 0;
    opt.skip_luhn = true;
    bad += want(payment_identifier::card_verify("4111111111111112", d, opt).valid, "skip luhn");
    opt.skip_luhn = false;
    bad += want(payment_identifier::card_verify("6212345678901234", d, opt).valid, "unionpay skips luhn");
    opt.luhn_unionpay = true;
    bad += want(!payment_identifier::card_verify("6212345678901234", d, opt).valid, "unionpay luhn on");
    return bad;
}
