//
//  EmailNormalizerTests.swift
//  SwiftEmailValidator
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//

import XCTest
@testable import SwiftEmailValidator
import SwiftPublicSuffixList

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
        let validator: (String) -> Bool = { PublicSuffixList.isUnrestricted($0, rules: [["com"]]) }

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
        let validator: (String) -> Bool = { PublicSuffixList.isUnrestricted($0, rules: [["com"]]) }
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
}
