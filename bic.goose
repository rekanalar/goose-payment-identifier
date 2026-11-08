namespace payment_identifier;

import std;

// The ISO 3166-1 alpha-2 codes plus XK, two letters each.
const BIC_COUNTRIES: const u8[:] = "ADAEAFAGAIALAMAOAQARASATAUAWAXAZBABBBDBEBFBGBHBIBJBLBMBNBOBQBRBSBTBVBWBYBZCACCCDCFCGCHCICKCLCMCNCOCRCUCVCWCXCYCZDEDJDKDMDODZECEEEGEHERESETFIFJFKFMFOFRGAGBGDGEGFGGGHGIGLGMGNGPGQGRGSGTGUGWGYHKHMHNHRHTHUIDIEILIMINIOIQIRISITJEJMJOJPKEKGKHKIKMKNKPKRKWKYKZLALBLCLILKLRLSLTLULVLYMAMCMDMEMFMGMHMKMLMMMNMOMPMQMRMSMTMUMVMWMXMYMZNANCNENFNGNINLNONPNRNUNZOMPAPEPFPGPHPKPLPMPNPRPSPTPWPYQARERORSRURWSASBSCSDSESGSHSISJSKSLSMSNSOSRSSSTSVSXSYSZTCTDTFTGTHTJTKTLTMTNTOTRTTTVTWTZUAUGUMUSUYUZVAVCVEVGVIVNVUWFWSXKYEYTZAZMZW";

struct BicParts {
    bank: const u8[:],
    country: const u8[:],
    location: const u8[:],
    branch: const u8[:],
    test: bool,
}

fn bic_country_ok(a: u8, b: u8) -> bool {
    var i = 0;
    while i + 1 < BIC_COUNTRIES.len {
        if BIC_COUNTRIES[i] == a && BIC_COUNTRIES[i + 1] == b { return true; }
        i += 2;
    }
    return false;
}

fn bic_compact(out: u8[>..]&, s: const u8[:]) -> i64 {
    return clean(out, s, MAX_BIC_INPUT);
}

// The fault of a compact BIC: length, then format, then country.
fn bic_fault(c: const u8[:]) -> i64 {
    if c.len != 8 && c.len != 11 { return ERR_LENGTH; }
    for i in 0..6 {
        if !(c[i] >= 'A' && c[i] <= 'Z') { return ERR_FORMAT; }
    }
    if !bic_country_ok(c[4], c[5]) { return ERR_COUNTRY; }
    return OK;
}

fn bic_validate(s: const u8[:]) -> i64 {
    var c: u8[>..] = [];
    let f = bic_compact(c, s);
    if f != OK { return f; }
    return bic_fault(c);
}

// Splits a valid BIC. The parts are slices of buf, which the caller keeps.
// The test flag is set when the second location character is 0.
fn bic_parts(buf: u8[>..]&, s: const u8[:]) -> BicParts, i64 {
    let none = BicParts { bank: "", country: "", location: "", branch: "", test: false };
    var f = bic_compact(buf, s);
    if f == OK { f = bic_fault(buf); }
    if f != OK { return none, f; }
    let parts = BicParts {
        bank: buf[..4],
        country: buf[4..6],
        location: buf[6..8],
        branch: buf[8..],
        test: buf[7] == '0',
    };
    return parts, OK;
}
