namespace suite;

import std;
import payment_identifier from "../..";

fn flag(a: bool, b: bool, what: const u8[:], s: const u8[:]) -> i64 {
    if a != b { print("FAIL: ", what, " [", s, "]"); return 1; }
    return 0;
}

fn id_of(b: payment_identifier::Brands&, k: i64) -> const u8[:] {
    if k < 0 { return ""; }
    return payment_identifier::brands_all(b)[k].id;
}

// The ids of the brands that fit, joined by commas.
fn hits_text(text: u8[>..]&, s: const u8[:], b: payment_identifier::Brands&) {
    var found: i64[>..] = [];
    text.clear();
    payment_identifier::card_match(found, s, b);
    for j in 0..found.len {
        if j > 0 { text.push(','); }
        text.append(payment_identifier::brands_all(b)[found[j]].id);
    }
}

fn run_card() -> i64 {
    var bad = 0;
    var b = payment_identifier::brands_default();
    var text: u8[>..] = [];
    for i in 0..NUM_CASES.len {
        let r = payment_identifier::card_verify(NUM_CASES[i].s, b, payment_identifier::number_options());
        bad += flag(r.valid, NUM_CASES[i].valid, "number valid", NUM_CASES[i].s);
        bad += flag(r.potentially_valid, NUM_CASES[i].pot, "number potentially valid", NUM_CASES[i].s);
        if id_of(b, r.brand) != NUM_CASES[i].brand { print("FAIL: brand [", NUM_CASES[i].s, "] got ", id_of(b, r.brand), " want ", NUM_CASES[i].brand); bad += 1; }
        hits_text(text, NUM_CASES[i].s, b);
        if text != NUM_CASES[i].hits { print("FAIL: hits [", NUM_CASES[i].s, "] got ", text, " want ", NUM_CASES[i].hits); bad += 1; }
    }
    for i in 0..DATE_CASES.len {
        let c = DATE_CASES[i];
        let r = payment_identifier::expiry_verify(c.s, NOW_YEAR, NOW_MONTH);
        bad += flag(r.valid, c.valid, "expiry valid", c.s);
        bad += flag(r.potentially_valid, c.pot, "expiry potentially valid", c.s);
        if r.month != c.month || r.year != c.year { print("FAIL: expiry parts [", c.s, "] ", r.month, " ", r.year); bad += 1; }
    }
    for i in 0..MONTH_CASES.len {
        let c = MONTH_CASES[i];
        let r = payment_identifier::month_verify(c.s);
        bad += flag(r.valid, c.valid, "month valid", c.s);
        bad += flag(r.potentially_valid, c.pot, "month potentially valid", c.s);
    }
    for i in 0..YEAR_CASES.len {
        let c = YEAR_CASES[i];
        let r = payment_identifier::year_verify(c.s, NOW_YEAR, c.n);
        bad += flag(r.valid, c.valid, "year valid", c.s);
        bad += flag(r.potentially_valid, c.pot, "year potentially valid", c.s);
    }
    for i in 0..CODE_CASES.len {
        let c = CODE_CASES[i];
        let r = payment_identifier::code_verify(c.s, c.n);
        bad += flag(r.valid, c.valid, "code valid", c.s);
        bad += flag(r.potentially_valid, c.pot, "code potentially valid", c.s);
    }
    for i in 0..NAME_CASES.len {
        let c = NAME_CASES[i];
        let r = payment_identifier::cardholder_verify(c.s);
        bad += flag(r.valid, c.valid, "name valid", c.s);
        bad += flag(r.potentially_valid, c.pot, "name potentially valid", c.s);
    }
    for i in 0..POSTAL_CASES.len {
        let c = POSTAL_CASES[i];
        let r = payment_identifier::postal_verify(c.s, c.n);
        bad += flag(r.valid, c.valid, "postal valid", c.s);
        bad += flag(r.potentially_valid, c.pot, "postal potentially valid", c.s);
    }
    return bad;
}
