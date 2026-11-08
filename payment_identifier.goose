// payment_identifier - payment identifiers for Goose.
//
// The package checks and builds IBANs, BICs, ISO 11649 creditor
// references, US ABA routing numbers and payment card numbers. It holds
// the ISO 7064 check-digit family and the Luhn algorithm.
//
// The repository is goose-payment-identifier. The import name is
// "payment_identifier". Every file of the package declares that namespace.
namespace payment_identifier;

import std;
import text;
import iso7064;
import luhn;
import iban_registry;
import iban;
import bic;
import reference;
import national;
import card_brands;
import card;

// Longest input, in bytes, that each family of calls accepts. A call
// checks the length before any other work.
const MAX_IBAN_INPUT: i64 = 64;
const MAX_BIC_INPUT: i64 = 16;
const MAX_REFERENCE_INPUT: i64 = 40;
const MAX_CARD_INPUT: i64 = 32;
const MAX_ALGO_INPUT: i64 = 64;
const MAX_DATE_INPUT: i64 = 12;
const MAX_CODE_INPUT: i64 = 8;
const MAX_POSTAL_INPUT: i64 = 16;
const MAX_NAME_INPUT: i64 = 255;

// Fault codes. OK is zero.
const OK: i64 = 0;
const ERR_EMPTY: i64 = 1;
const ERR_TOO_LONG: i64 = 2;
const ERR_CHARS: i64 = 3;
const ERR_COUNTRY: i64 = 4;
const ERR_LENGTH: i64 = 5;
const ERR_STRUCTURE: i64 = 6;
const ERR_CHECK_DIGITS: i64 = 7;
const ERR_NATIONAL: i64 = 8;
const ERR_QR_IBAN: i64 = 9;
const ERR_FORMAT: i64 = 10;

// Result of a national BBAN check.
const NATIONAL_NONE: i64 = 0;
const NATIONAL_OK: i64 = 1;
const NATIONAL_BAD: i64 = 2;

struct IbanOptions {
    allow_qr_iban: bool,
    national: bool,
}
