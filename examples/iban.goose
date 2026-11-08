// Check an IBAN, read its parts, build one from a BBAN and print it.
import std;
import payment_identifier from "..";

fn main() {
    let text = "NL91 ABNA 0417 1643 00";
    let f = payment_identifier::iban_validate(text);
    print("valid: ", f == payment_identifier::OK);

    var buf: u8[>..] = [];
    let parts, fault = payment_identifier::iban_extract(buf, text);
    if fault == payment_identifier::OK {
        print("country ", parts.country, ", bank ", parts.bank, ", account ", parts.account);
    }

    var iban: u8[>..] = [];
    if payment_identifier::iban_compose(iban, "DE", "370400440532013000") == payment_identifier::OK {
        print("composed: ", iban);
    }

    var shown: u8[>..] = [];
    payment_identifier::iban_print(shown, iban, " ");
    print("print form: ", shown);
    print("SEPA: ", payment_identifier::is_sepa("DE"));
    print("registry release: ", payment_identifier::registry_version());
    return 0;
}
