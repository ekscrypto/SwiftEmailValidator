//
//  EmailNormalizerTests.swift
//  SwiftEmailValidator
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//

import XCTest
@testable import SwiftEmailValidator

final class EmailNormalizerTests: XCTestCase {

    // MARK: - Pure pass-through

    func testAsciiIsUnchanged() {
        XCTAssertEqual(EmailNormalizer.nfkc("user@example.com"), "user@example.com")
    }

    func testEmptyStringIsUnchanged() {
        XCTAssertEqual(EmailNormalizer.nfkc(""), "")
    }

    func testEmojiIsUnchanged() {
        // Emoji are not compatibility-equivalent to anything; NFKC must leave them alone.
        XCTAssertEqual(EmailNormalizer.nfkc("🎉@example.com"), "🎉@example.com")
    }

    // MARK: - Compatibility mappings

    func testFullwidthCommercialAt() {
        // U+FF20 FULLWIDTH COMMERCIAL AT → '@'
        XCTAssertEqual(EmailNormalizer.nfkc("user\u{FF20}example.com"), "user@example.com")
    }

    func testFullwidthDigits() {
        // U+FF11..U+FF19 FULLWIDTH DIGIT ONE..NINE → '1'..'9'
        XCTAssertEqual(EmailNormalizer.nfkc("user\u{FF11}\u{FF12}\u{FF13}@example.com"),
                       "user123@example.com")
    }

    func testFullwidthLatinLetters() {
        // U+FF21..U+FF3A FULLWIDTH LATIN CAPITAL A..Z → 'A'..'Z'
        XCTAssertEqual(EmailNormalizer.nfkc("\u{FF21}\u{FF22}\u{FF23}@example.com"),
                       "ABC@example.com")
    }

    func testLatinLigature() {
        // U+FB01 LATIN SMALL LIGATURE FI → 'fi'
        XCTAssertEqual(EmailNormalizer.nfkc("\u{FB01}nance@example.com"),
                       "finance@example.com")
    }

    func testSuperscriptDigit() {
        // U+00B2 SUPERSCRIPT TWO → '2'
        XCTAssertEqual(EmailNormalizer.nfkc("user\u{00B2}@example.com"),
                       "user2@example.com")
    }

    func testBlackLetterCapital() {
        // U+210C BLACK-LETTER CAPITAL H → 'H'
        XCTAssertEqual(EmailNormalizer.nfkc("\u{210C}ello@example.com"),
                       "Hello@example.com")
    }

    func testFullwidthPeriod() {
        // U+FF0E FULLWIDTH FULL STOP → '.'
        XCTAssertEqual(EmailNormalizer.nfkc("user@example\u{FF0E}com"),
                       "user@example.com")
    }

    // MARK: - Canonical composition

    func testDecomposedAcuteBecomesPrecomposed() {
        let decomposed = "cafe\u{0301}@example.com"   // e + combining acute
        let precomposed = "caf\u{00E9}@example.com"    // é
        XCTAssertEqual(EmailNormalizer.nfkc(decomposed), precomposed)
    }

    // MARK: - Things NFKC should NOT do

    func testDoesNotLowercase() {
        // Case must be preserved — RFC 5321 §2.4 makes local parts case-sensitive.
        XCTAssertEqual(EmailNormalizer.nfkc("User.Name@Example.COM"), "User.Name@Example.COM")
    }

    func testDoesNotStripSurroundingWhitespace() {
        // Normalization is a pure Unicode transform, not a sanitizer.
        XCTAssertEqual(EmailNormalizer.nfkc("  user@example.com  "), "  user@example.com  ")
    }

    // MARK: - Composition with EmailSyntaxValidator

    func testNormalizationEnablesValidationOfFullwidthAt() {
        // A fullwidth '＠' fails validation directly, but normalizing first fixes it.
        let input = "user\u{FF20}site.com"
        let validator: (String) -> Bool = comOnlyDomainValidator

        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted(input, domainValidator: validator),
                       "Precondition: raw fullwidth '＠' must not validate as an email")

        let normalized = EmailNormalizer.nfkc(input)
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(normalized, domainValidator: validator),
                      "After NFKC, fullwidth '＠' becomes '@' and the address should validate")
    }

    // MARK: - Quoted-string behaviour

    func testQuotedStringDelimitersArePreserved() {
        // The quote character (U+0022), backslash (U+005C), and '@' (U+0040) are all ASCII,
        // so NFKC must leave them untouched — the quoting structure round-trips.
        let input = #""user name"@example.com"#
        XCTAssertEqual(EmailNormalizer.nfkc(input), input)
    }

    func testQuotedStringInteriorIsNormalized() {
        // Deliberate: normalizing inside the quotes is what defeats quote-wrapped homograph
        // spoofing. The quoted/unquoted variants collapse to byte-identical outputs aside
        // from the quote delimiters themselves.
        let unquoted = "\u{FF41}\u{FF44}\u{FF4D}\u{FF49}\u{FF4E}@example.com"           // ａｄｍｉｎ@
        let quoted   = "\"\u{FF41}\u{FF44}\u{FF4D}\u{FF49}\u{FF4E}\"@example.com"       // "ａｄｍｉｎ"@
        XCTAssertEqual(EmailNormalizer.nfkc(unquoted), "admin@example.com")
        XCTAssertEqual(EmailNormalizer.nfkc(quoted),   "\"admin\"@example.com")
    }

    func testNormalizedQuotedOutputStillParses() {
        // Sanity-check the "structurally safe" claim: the validator parses the NFKC output
        // as a quoted-string local part, not as garbage.
        let input = "\"\u{FF41}\u{FF44}\u{FF4D}\u{FF49}\u{FF4E}\"@example.com"
        let normalized = EmailNormalizer.nfkc(input)
        let validator: (String) -> Bool = comOnlyDomainValidator
        let mailbox = EmailSyntaxValidator.mailbox(from: normalized, domainValidator: validator)
        XCTAssertEqual(mailbox?.localPart, .quotedString("admin"))
        XCTAssertEqual(mailbox?.host, .domain("example.com"))
    }

    func testNormalizationProducesStableIdentityForCompatibilityVariants() {
        // Three superficially-different inputs that collapse to the same canonical form.
        let plain     = "user123@example.com"
        let fullwidth = "\u{FF55}\u{FF53}\u{FF45}\u{FF52}\u{FF11}\u{FF12}\u{FF13}@example.com"
        let mixed     = "use\u{FF52}1\u{FF12}3@example.com" // mix of ASCII and fullwidth

        XCTAssertEqual(EmailNormalizer.nfkc(plain), plain)
        XCTAssertEqual(EmailNormalizer.nfkc(fullwidth), plain)
        XCTAssertEqual(EmailNormalizer.nfkc(mixed), plain)
    }

    // MARK: - Length non-preservation — normalize → validate contract

    func testNfkcExpansionIsRejectedByValidator() {
        // U+FDFA (ARABIC LIGATURE SALLALLAHOU ALAYHE WASALLAM) NFKC-expands to 18 scalars
        // including ASCII SPACE. The normalizer produces the expansion as-is; the downstream
        // validator must reject it because atext disallows SPACE. This pins the
        // "normalize-then-validate" contract: normalization is not a length-preserving
        // sanitizer, and validation must run *after* normalization, not before.
        let input = "user\u{FDFA}@example.com"
        let normalized = EmailNormalizer.nfkc(input)

        XCTAssertTrue(normalized.contains(" "),
                      "Precondition: U+FDFA NFKC expansion must contain ASCII SPACE")
        XCTAssertGreaterThan(normalized.utf8.count, input.utf8.count,
                             "Precondition: NFKC must expand this input")

        let validator: (String) -> Bool = comOnlyDomainValidator
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted(normalized,
                                                               compatibility: .unicode,
                                                               domainValidator: validator),
                       "Expanded form contains SPACE and must not validate as a mailbox")
    }

    // MARK: - NFC API (RFC 6532 §3.1 compliant)

    func testNfcAsciiIsUnchanged() {
        XCTAssertEqual(EmailNormalizer.nfc("user@example.com"), "user@example.com")
    }

    func testNfcComposesDecomposedAccent() {
        // Canonical composition: the one thing NFC and NFKC agree on.
        let decomposed = "cafe\u{0301}@example.com"
        let precomposed = "caf\u{00E9}@example.com"
        XCTAssertEqual(EmailNormalizer.nfc(decomposed), precomposed)
    }

    func testNfcDoesNotFoldCompatibilityVariants() {
        // This is the point of NFC-vs-NFKC: fullwidth, ligature, and superscript
        // forms survive NFC untouched. RFC 6532 §3.1 prescribes this behavior so that
        // name spellings are preserved.
        let fullwidthAt = "user\u{FF20}example.com"
        XCTAssertEqual(EmailNormalizer.nfc(fullwidthAt), fullwidthAt)

        let ligature = "\u{FB01}nance@example.com"
        XCTAssertEqual(EmailNormalizer.nfc(ligature), ligature)

        let superscript = "user\u{00B2}@example.com"
        XCTAssertEqual(EmailNormalizer.nfc(superscript), superscript)
    }

    func testNfcPreservesCaseAndWhitespace() {
        XCTAssertEqual(EmailNormalizer.nfc("User.Name@Example.COM"), "User.Name@Example.COM")
        XCTAssertEqual(EmailNormalizer.nfc("  user@example.com  "), "  user@example.com  ")
    }

    func testNfcAndNfkcAgreeOnPureAscii() {
        let ascii = "simple.user+tag@example.com"
        XCTAssertEqual(EmailNormalizer.nfc(ascii), EmailNormalizer.nfkc(ascii))
        XCTAssertEqual(EmailNormalizer.nfc(ascii), ascii)
    }

    func testNfcAndNfkcDivergeOnCompatibilityInput() {
        // Sanity check that the two APIs are not aliases — callers choosing NFC get a
        // materially different result than callers choosing NFKC.
        let input = "user\u{FF20}example.com" // fullwidth '＠'
        XCTAssertNotEqual(EmailNormalizer.nfc(input), EmailNormalizer.nfkc(input))
        XCTAssertEqual(EmailNormalizer.nfc(input), input)
        XCTAssertEqual(EmailNormalizer.nfkc(input), "user@example.com")
    }

    // MARK: - Idempotency / stability (UAX #15 D8/D9)

    func testNfcIsIdempotent() {
        // UAX #15 D8: NFC is stable under repeated application.
        let inputs = [
            "user@example.com",
            "cafe\u{0301}@example.com",                // decomposed → composed on first pass
            "\u{FF21}\u{FF22}\u{FF23}@example.com",    // fullwidth — NFC leaves alone
            "🎉@example.com",
            "\"\u{FF41}\u{FF44}\u{FF4D}\u{FF49}\u{FF4E}\"@example.com",
        ]
        for input in inputs {
            let once = EmailNormalizer.nfc(input)
            let twice = EmailNormalizer.nfc(once)
            XCTAssertEqual(once, twice, "NFC must be idempotent for input: \(input)")
        }
    }

    func testNfkcIsIdempotent() {
        // UAX #15 D9: NFKC is stable under repeated application.
        let inputs = [
            "user@example.com",
            "cafe\u{0301}@example.com",
            "\u{FF21}\u{FF22}\u{FF23}@example.com",
            "user\u{FDFA}@example.com",                // expansion case — must still stabilize
            "\u{FB01}nance@example.com",
            "user\u{00B2}@example.com",
        ]
        for input in inputs {
            let once = EmailNormalizer.nfkc(input)
            let twice = EmailNormalizer.nfkc(once)
            XCTAssertEqual(once, twice, "NFKC must be idempotent for input: \(input)")
        }
    }

    func testNfkcOutputIsAlsoInNfc() {
        // UAX #15: NFKC ⊇ NFC. Re-applying NFC to NFKC output must be a no-op.
        let inputs = [
            "user@example.com",
            "\u{FF21}\u{FF22}\u{FF23}@example.com",
            "user\u{FDFA}@example.com",
            "\u{FB01}nance@example.com",
            "cafe\u{0301}@example.com",
        ]
        for input in inputs {
            let nfkc = EmailNormalizer.nfkc(input)
            XCTAssertEqual(EmailNormalizer.nfc(nfkc), nfkc,
                           "NFKC output must already be in NFC for input: \(input)")
        }
    }
}
