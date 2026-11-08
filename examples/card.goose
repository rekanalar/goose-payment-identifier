// Recognize a card brand as the user types, verify the number, and show it masked.
import std;
import payment_identifier from "..";

fn main() {
    var brands = payment_identifier::brands_default();

    var hits: i64[>..] = [];
    payment_identifier::card_match(hits, "4", brands);
    print("digits '4' still fit ", hits.len, " brands");

    let number = "4111 1111 1111 1111";
    let check = payment_identifier::card_verify(number, brands, payment_identifier::number_options());
    print("valid: ", check.valid, ", brand: ", payment_identifier::brands_all(brands)[check.brand].name);

    var shown: u8[>..] = [];
    payment_identifier::card_gaps(shown, number, brands);
    print("masked: ", shown);

    // The caller gives the clock: year 2026, month 11.
    let expiry = payment_identifier::expiry_verify("12/28", 2026, 11);
    print("expiry valid: ", expiry.valid, ", month ", expiry.month, ", year ", expiry.year);
    print("code valid: ", payment_identifier::code_verify("123", 3).valid);
    return 0;
}
