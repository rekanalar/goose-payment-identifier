# goose-payment-identifier

[![ci](https://github.com/rekanalar/goose-payment-identifier/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-payment-identifier/actions/workflows/ci.yml)

Payment identifiers for Goose, in pure Goose. The package checks and builds
IBANs, BICs, ISO 11649 creditor references, US ABA routing numbers and
payment card numbers. It holds the ISO 7064 check-digit family and Luhn.

## Install

Add this line to the root file of your program:

```goose
import payment_identifier from "rekanalar/goose-payment-identifier@v0.1.0";
```

## Example

```goose
import std;
import payment_identifier from "rekanalar/goose-payment-identifier@v0.1.0";

fn main() {
    print(payment_identifier::iban_validate("NL91 ABNA 0417 1643 00") == payment_identifier::OK);

    var brands = payment_identifier::brands_default();
    let check = payment_identifier::card_verify("4111 1111 1111 1111", brands,
                                                payment_identifier::number_options());
    print(check.valid);

    var shown: u8[>..] = [];
    payment_identifier::card_gaps(shown, "4111 1111 1111 1111", brands);
    print(shown);       // 4111 11** **** 1111
    return 0;
}
```

More programs are in `examples/`.

## How a call answers

A call that can fail returns a fault code. `OK` is zero. Other codes are
`ERR_EMPTY`, `ERR_TOO_LONG`, `ERR_CHARS`, `ERR_COUNTRY`, `ERR_LENGTH`,
`ERR_STRUCTURE`, `ERR_CHECK_DIGITS`, `ERR_NATIONAL`, `ERR_QR_IBAN` and `ERR_FORMAT`. A call that writes text takes a growable
buffer `u8[>..]&` first. A part of a result is a slice of a buffer that
the caller keeps alive.

## Functions

### IBAN

| Call | Result |
|---|---|
| `iban_compact(out, s)` | upper case text without space and hyphen |
| `iban_validate(s)` | the first fault: bound, characters, country, length, structure, check digits |
| `iban_is_valid(s)` | `bool` |
| `iban_faults(faults, s)` | fills `faults: i64[>..]&` with every fault |
| `iban_check_digits(out, country, bban)` | two check digits |
| `iban_compose(out, country, bban)` | the whole IBAN |
| `iban_electronic(out, s)`, `iban_print(out, s, sep)` | electronic form, print form in groups of four |
| `iban_extract(buf, s)` | `IbanParts` (country, check digits, BBAN, bank, branch, account) and a fault |
| `bban_validate(country, bban)` | length and structure of one BBAN |
| `iban_validate_national(s)` | `NATIONAL_NONE`, `NATIONAL_OK` or `NATIONAL_BAD` |
| `national_check(country, bban)` | the national rule on a BBAN of the right shape |
| `iban_validate_with(s) { country, bban => ... }` | like `iban_validate`, plus a rule of the caller |
| `iban_validate_o(s, opts)` | `IbanOptions { allow_qr_iban, national }` |
| `is_sepa(code)`, `is_qr_iban(s)` | SEPA country, Swiss or Liechtenstein QR-IBAN |
| `country_spec(code)`, `country_count()`, `country_at(i)` | the registry: 89 countries; `i` must be below `country_count()` |
| `registry_version()` | `101` |

### BIC, reference, routing number

| Call | Result |
|---|---|
| `bic_validate(s)`, `bic_compact(out, s)` | ISO 9362 check, compact form |
| `bic_parts(buf, s)` | `BicParts` (bank, country, location, branch, test flag) |
| `reference_validate(s)` | ISO 11649 creditor reference |
| `reference_check_digits(out, body)` | two check digits for a body |
| `reference_compact(out, s)`, `reference_print(out, s)` | compact form, blocks of four |
| `routing_validate(s)` | US ABA routing number |

### ISO 7064 and Luhn

| Call | Result |
|---|---|
| `mod97_10_checksum(s)`, `mod97_10_value(s)`, `mod97_10_digits(out, s)`, `mod97_10_valid(s)` | mod 97-10 |
| `mod11_10_*`, `mod11_2_*` | `_checksum`, `_digit` (an index) and `_valid` |
| `mod37_2_*`, `mod37_36_*` | the same, with an `alphabet` parameter |
| `luhn_checksum`, `luhn_digit`, `luhn_valid` | Luhn mod N, with an `alphabet` parameter |

A checksum call returns -1, and a valid call returns false, for a byte
outside the alphabet. A digit call returns an index into the alphabet.

### Cards

| Call | Result |
|---|---|
| `brands_default()` | `Brands` with the 15 brands of `credit-card-type` |
| `brands_add`, `brands_update`, `brands_remove`, `brands_move`, `brands_all` | edit the list or read it |
| `brand_new`, `brand_add_pattern`, `brand_add_gap`, `brand_add_length` | build a brand |
| `card_match(hits, digits, b)` | the brands that still fit, or the best one |
| `card_brand(digits, b)` | the one brand that fits, or -1 |
| `card_verify(digits, b, opts)` | `NumberCheck` (valid, potentially valid, brand, cause) |
| `expiry_verify(s, year_now, month_now)` | `ExpiryCheck` (valid, potentially valid, month, year) |
| `month_verify(s)`, `year_verify(s, year_now, years_ahead = 19)` | `CodeCheck` |
| `code_verify(s, size)` | `CodeCheck` for CVV, CVC, CID |
| `cardholder_verify(s)`, `postal_verify(s, min_length = 2)` | `CodeCheck` |
| `card_mask(out, digits)`, `card_last4(out, digits)`, `card_gaps(out, digits, b)` | masked text |
| `is_test_card(digits)` | one of the public test numbers |

The brand rules follow `credit-card-type` and `card-validator`. An empty
number fits all 15 brands. The best match exists only when every hit has
a full prefix match. Then it is the longest prefix.

## Limits

- **Registry release 101.** The table was generated on 2026-11-08 from
  release 101 of the SWIFT IBAN registry. It holds 89 countries. The
  registry changes: countries join, and lengths and structures change.
  Update the package when SWIFT publishes a new release.
- **Bank, branch and account positions** come from the `schwifty` registry.
  Where a country has national check digits outside the account range,
  the account range excludes them.
- **No German national check.** `ibantools` has none. `schwifty` holds
  many bank-specific methods. The references disagree on the rule.
- **No unofficial country.** `ibantools` and `schwifty` accept
  countries that the registry does not list. `python-stdnum` does not. This
  package follows the registry.
- **21 national checks.** Other countries give `NATIONAL_NONE`, never
  `NATIONAL_OK`. A text that is not a valid IBAN gives `NATIONAL_BAD`.
  - From `ibantools`: BA, BE, CZ, SK, EE, ES, FR, MC, HR.
  - From `ibantools`, continued: HU, ME, MK, NO, PL, PT, RS, SI.
  - From `schwifty`: FI, IS, IT, SM.
- **FI, IS, IT and SM follow `schwifty`.** `ibantools` has no rule for
  them. It accepts `FI6879826661004681`, and the Finnish rule of
  `schwifty` rejects it. Plain `iban_validate` accepts it. The national
  options reject it.
- **No bank directory.** The package does not map a bank code to a bank
  name or a BIC. `schwifty` does.
- **The caller gives the clock.** Expiry and year calls take the current
  year and month. The package does not read the time.
- **UnionPay skips Luhn** unless `luhn_unionpay` is true, as
  `card-validator` does.
- **Brand ranges change.** Networks add ranges. Edit the list with
  `brands_add` and `brands_update`.
- **Mask rule.** At least six digits stay hidden. At most six show at the
  start and four at the end. A short number shows fewer.
- **Stricter than the references.** An IBAN with check digits 00, 01 or 99
  fails, because mod 97-10 never gives them. `python-stdnum` accepts them.
  A tab or another control byte in a card number fails. `card-validator`
  strips any white space.
- **Test card numbers** come from the public documents of the networks
  and of payment processors. The list is not a copy of `go-credit-card`.

## Security

The package parses text from people you do not know. These protections
go beyond `ibantools`, `schwifty` and `card-validator`:

- **ASCII only.** Letters and digits of ASCII only. Fullwidth digits,
  Arabic-Indic digits, look-alike letters, zero-width marks, NUL, control
  bytes and bad UTF-8 give `ERR_CHARS`. The cardholder name is the one
  exception: valid UTF-8 without control characters, up to 255 bytes.
- **Bound first.** Each call compares the length with its limit before it
  does other work. A text of one million characters fails in under 10 ms.
  The limits are 64 bytes for an IBAN and 16 for a BIC. They are 40 for a
  reference, 32 for a card number and 12 for an expiry date.
- **No struct holds a whole card number.** Results hold flags, an index
  and a fault code. No public call returns a whole card number. The
  masked outputs show at most ten digits.
- **No wipe call.** `go-credit-card` has `Wipe`. It clears one buffer,
  but not the copies that the runtime and the program make. This package
  does not offer a call that suggests otherwise. Keep a card number in
  memory for as short a time as you can.
- **Check digits 02 to 98 only.** Remainder 1 alone also admits 00, 01
  and 99.
- **Short brand patterns.** A brand pattern holds at most eight digits.
  A brand cannot store a card number.

Risks that stay:

- A valid IBAN does not prove that the account exists. A valid card number
  does not prove that the card is live. Only the bank or the card network
  can tell.
- The registry ages. See the limits above.
- The text you pass in stays in your own buffers. The package cannot clear
  them. Do not log a card number.
- A block that you pass to `iban_validate_with` is your code. The package
  cannot check it.

## License

MIT
