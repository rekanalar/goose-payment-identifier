namespace suite;

import std;
import payment_identifier from "../..";

fn run_bic() -> i64 {
    var bad = 0;
    bad += want(payment_identifier::bic_validate("AGRIFRPP882") == payment_identifier::OK, "bic 11");
    bad += want(payment_identifier::bic_validate("ABNA BE 2A") == payment_identifier::OK, "bic spaces");
    bad += want(payment_identifier::bic_validate("AGRIFRPP") == payment_identifier::OK, "bic 8");
    bad += want(payment_identifier::bic_validate("agriFRPP") == payment_identifier::OK, "bic lower");
    bad += want(payment_identifier::bic_validate("AGRIFRPP8") == payment_identifier::ERR_LENGTH, "bic length");
    bad += want(payment_identifier::bic_validate("AGRIF2PP") == payment_identifier::ERR_FORMAT, "bic digit in country");
    bad += want(payment_identifier::bic_validate("AGRIQQPP") == payment_identifier::ERR_COUNTRY, "bic unknown country");
    bad += want(payment_identifier::bic_validate("AGRIXKPP") == payment_identifier::OK, "bic Kosovo");
    bad += want(payment_identifier::bic_validate("") == payment_identifier::ERR_EMPTY, "bic empty");
    var buf: u8[>..] = [];
    let p, f = payment_identifier::bic_parts(buf, "ABNANL2A");
    bad += want(f == payment_identifier::OK, "parts ok");
    bad += eq(p.bank, "ABNA", "bank");
    bad += eq(p.country, "NL", "country");
    bad += eq(p.location, "2A", "location");
    bad += eq(p.branch, "", "branch");
    bad += want(!p.test, "not a test bic");
    var buf2: u8[>..] = [];
    let q, g = payment_identifier::bic_parts(buf2, "DEUTDEFF500");
    bad += eq(q.branch, "500", "branch 500");
    let r, h = payment_identifier::bic_parts(buf2, "DEUTDEF0");
    bad += want(r.test, "test bic");
    // ISO 11649 and ABA.
    var out: u8[>..] = [];
    bad += want(payment_identifier::reference_validate("RF18 5390 0754 7034") == payment_identifier::OK, "ref ok");
    bad += want(payment_identifier::reference_validate("RF18 5390 0754 70Y") == payment_identifier::OK, "ref letters");
    bad += want(payment_identifier::reference_validate("RF17 5390 0754 7034") == payment_identifier::ERR_CHECK_DIGITS, "ref check");
    bad += want(payment_identifier::reference_validate("XX18539007547034") == payment_identifier::ERR_FORMAT, "ref prefix");
    bad += want(payment_identifier::reference_validate("RF18") == payment_identifier::ERR_LENGTH, "ref short");
    bad += want(payment_identifier::reference_validate("RF18.5390/0754:7034") == payment_identifier::OK, "ref separators");
    payment_identifier::reference_print(out, "RF18539007547034");
    bad += eq(out, "RF18 5390 0754 7034", "ref print");
    payment_identifier::reference_compact(out, "RF18 5390 0754 7034");
    bad += eq(out, "RF18539007547034", "ref compact");
    bad += want(payment_identifier::reference_check_digits(out, "539007547034") == payment_identifier::OK, "ref digits ok");
    bad += eq(out, "18", "ref digits");
    bad += want(payment_identifier::routing_validate("111000025") == payment_identifier::OK, "aba ok");
    bad += want(payment_identifier::routing_validate("112000025") == payment_identifier::ERR_CHECK_DIGITS, "aba check");
    bad += want(payment_identifier::routing_validate("11100002") == payment_identifier::ERR_LENGTH, "aba length");
    bad += want(payment_identifier::routing_validate("11100002X") == payment_identifier::ERR_FORMAT, "aba letter");
    return bad;
}
