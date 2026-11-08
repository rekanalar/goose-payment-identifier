import std;
import payment_identifier from "..";
import suite from "./suite";

fn check(ok: bool, what: const u8[:]) -> i64 {
    if !ok { print("FAIL: ", what); return 1; }
    return 0;
}

fn main() {
    var bad = 0;
    bad += check(payment_identifier::mod97_10_value("99991234567890121414") == 90, "97-10 digits");
    bad += check(payment_identifier::mod97_10_valid("9999123456789012141490"), "97-10 valid");
    bad += check(payment_identifier::mod97_10_value("4354111611551114") == 31, "97-10 digits 2");
    bad += check(payment_identifier::mod97_10_valid("08686001256515001121751"), "97-10 valid 2");
    bad += check(payment_identifier::mod97_10_value("22181321402534321446701611") == 35, "97-10 digits 3");
    bad += check(payment_identifier::mod11_10_digit("79462") == 3, "11-10 digit");
    bad += check(payment_identifier::mod11_10_valid("794623"), "11-10 valid");
    bad += check(payment_identifier::mod11_10_digit("00200667308") == 5, "11-10 digit 2");
    bad += check(payment_identifier::mod11_2_digit("0794") == 0, "11-2 digit");
    bad += check(payment_identifier::mod11_2_digit("079") == 10, "11-2 X");
    bad += check(payment_identifier::mod11_2_valid("079X"), "11-2 valid X");
    bad += check(payment_identifier::mod11_2_checksum("079X") == 1, "11-2 checksum");
    bad += check(payment_identifier::mod37_2_valid("G123489654321Y"), "37-2 valid");
    bad += check(payment_identifier::mod37_2_digit("079", "0123456789X") == 10, "37-2 alphabet");
    bad += check(payment_identifier::mod37_36_checksum("A12425GABC1234002M") == 1, "37-36 checksum");
    bad += check(payment_identifier::mod37_36_valid("A12425GABC1234002M"), "37-36 valid");
    bad += check(payment_identifier::mod37_36_digit("00200667308", "0123456789") == 5, "37-36 alphabet");
    bad += check(payment_identifier::luhn_digit("7894") == 9, "luhn digit");
    bad += check(payment_identifier::luhn_valid("78949"), "luhn valid");
    bad += check(!payment_identifier::luhn_valid("78948"), "luhn invalid");
    bad += check(payment_identifier::luhn_valid("4111111111111111"), "luhn visa");
    let hex = "0123456789ABCDEF";
    let d = payment_identifier::luhn_digit("1234567890ABCDEF", hex);
    var t: u8[>..] = [];
    t.append("1234567890ABCDEF");
    t.push(hex[d]);
    bad += check(d >= 0 && payment_identifier::luhn_valid(t, hex), "luhn hex round trip");
    bad += check(payment_identifier::mod97_10_checksum("12?") == -1, "97-10 bad byte");
    bad += suite::run_iban();
    bad += suite::run_bic();
    bad += suite::run_ibantools();
    bad += suite::run_national();
    bad += suite::run_card();
    bad += suite::run_hostile();
    bad += suite::run_random();
    bad += suite::run_mask();
    bad += suite::run_brands();
    if bad > 0 { return 1; }
    print("ok");
    return 0;
}
