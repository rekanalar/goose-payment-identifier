// The check-digit algorithms: ISO 7064, Luhn, creditor reference, BIC and routing number.
import std;
import payment_identifier from "..";

fn main() {
    print("mod 97-10 valid: ", payment_identifier::mod97_10_valid("9999123456789012141490"));
    print("mod 11-10 digit: ", payment_identifier::mod11_10_digit("79462"));
    print("luhn valid: ", payment_identifier::luhn_valid("78949"));

    var digits: u8[>..] = [];
    payment_identifier::reference_check_digits(digits, "539007547034");
    print("reference check digits: ", digits);
    print("reference valid: ", payment_identifier::reference_validate("RF18 5390 0754 7034") == payment_identifier::OK);
    print("bic valid: ", payment_identifier::bic_validate("DEUTDEFF500") == payment_identifier::OK);
    print("routing valid: ", payment_identifier::routing_validate("111000025") == payment_identifier::OK);
    return 0;
}
