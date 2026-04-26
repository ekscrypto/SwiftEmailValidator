//
//  IDNAProcessingTests.swift
//  SwiftEmailValidatorIDNATests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  UTS #46 §4 Processing pipeline tests. Vectors are drawn from
//  IdnaTestV2.txt for cases that exercise the §4 steps this implementation
//  enforces (mapping, NFC, hyphen rules, label validity). Vectors that
//  exclusively test Bidi (RFC 5893) or CONTEXTJ are not asserted because
//  those checks are documented out-of-scope for this initial release.
//

import XCTest
@testable import SwiftEmailValidatorIDNA

final class IDNAProcessingTests: XCTestCase {

    // MARK: - ToASCII golden vectors

    func testToAsciiASCIIPassthrough() {
        XCTAssertEqual(IDNA.toAscii("example.com"), "example.com")
        XCTAssertEqual(IDNA.toAscii("EXAMPLE.COM"), "example.com",
                       "uppercase ASCII must be folded by §4 step 1")
    }

    func testToAsciiFullwidthMapping() {
        // Fullwidth ASCII (U+FF21..U+FF3A, U+FF41..U+FF5A) and the
        // fullwidth full stop U+FF0E all have explicit `mapped` entries.
        // Result: post-mapping the host becomes plain "example.com".
        XCTAssertEqual(IDNA.toAscii("ｅｘａｍｐｌｅ\u{FF0E}ｃｏｍ"), "example.com")
    }

    func testToAsciiPunycodeForUnicodeLabels() {
        XCTAssertEqual(IDNA.toAscii("münchen.de"), "xn--mnchen-3ya.de")
        XCTAssertEqual(IDNA.toAscii("café.fr"), "xn--caf-dma.fr")
        XCTAssertEqual(IDNA.toAscii("日本.jp"), "xn--wgv71a.jp")
    }

    func testToAsciiNontransitionalKeepsDeviation() {
        // ß (U+00DF) is a `deviation` character; nontransitional processing
        // (the default) keeps it as-is and Punycode-encodes the label.
        // Transitional would map it to `ss`.
        XCTAssertEqual(IDNA.toAscii("faß.de"), "xn--fa-hia.de")
    }

    func testToAsciiTransitionalMapsDeviation() {
        let opts = IDNA.Options(transitional: true)
        XCTAssertEqual(IDNA.toAscii("faß.de", options: opts), "fass.de")
    }

    func testToAsciiDecodesAndRevalidatesXNLabels() {
        // Round-trip: ACE label decodes, validates, re-encodes identically.
        XCTAssertEqual(IDNA.toAscii("xn--mnchen-3ya.de"), "xn--mnchen-3ya.de")
        // Mixed case `xn--` prefix still decodes.
        XCTAssertEqual(IDNA.toAscii("XN--MNCHEN-3YA.de"), "xn--mnchen-3ya.de")
    }

    func testToAsciiPreservesTrailingRootDot() {
        XCTAssertEqual(IDNA.toAscii("example.com."), "example.com.")
    }

    func testToAsciiRejectsConsecutiveDots() {
        XCTAssertNil(IDNA.toAscii("a..b"))
    }

    func testToAsciiRejectsLeadingTrailingHyphen() {
        XCTAssertNil(IDNA.toAscii("-foo.com"))
        XCTAssertNil(IDNA.toAscii("foo-.com"))
    }

    func testToAsciiRejectsDoubleHyphenAt34() {
        // `ab--cd` has hyphens at positions 3-4 and is not a valid `xn--`
        // label (decoder rejects empty body).
        XCTAssertNil(IDNA.toAscii("ab--cd.com"))
    }

    func testToAsciiAllowsXnPrefix() {
        // The hyphens-at-3-4 rule is suspended for genuine ACE labels.
        XCTAssertEqual(IDNA.toAscii("xn--mnchen-3ya.de"), "xn--mnchen-3ya.de")
    }

    func testToAsciiRejectsDisallowedScalars() {
        // U+0080 (C1 control) is `disallowed` per the mapping table.
        XCTAssertNil(IDNA.toAscii("a\u{0080}b.com"))
        // U+202E (RIGHT-TO-LEFT OVERRIDE) is also `disallowed`.
        XCTAssertNil(IDNA.toAscii("a\u{202E}b.com"))
    }

    // MARK: - UseSTD3ASCIIRules

    /// With STD3 on (the default), every ASCII scalar in a label must be
    /// LDH (`[A-Za-z0-9-]`). The modern preprocessed IDNA Mapping Table
    /// classifies `_`, `/`, `:`, `@`, `*`, `<`, `>`, `"`, and the C0/DEL
    /// controls as `valid` (with the informational `NV8` tag), so STD3
    /// enforcement must come from the validator, not the table status.
    func testToAsciiRejectsNonLDHASCIIWithSTD3() {
        let nonLDH: [Character] = ["_", "/", ":", "@", "*", "<", ">", "\"", "$", "+"]
        for c in nonLDH {
            XCTAssertNil(IDNA.toAscii("a\(c)b.com"),
                         "STD3 must reject ASCII '\(c)' in a label")
        }
        XCTAssertNil(IDNA.toAscii("a\u{0001}b.com"),
                     "STD3 must reject C0 control U+0001")
        XCTAssertNil(IDNA.toAscii("a\u{007F}b.com"),
                     "STD3 must reject DEL U+007F")
    }

    /// Fullwidth-mapped non-LDH (e.g. U+FF0F → U+002F) must also be caught
    /// by STD3, because the LDH check runs after step 1 mapping.
    func testToAsciiRejectsFullwidthNonLDHWithSTD3() {
        // U+FF0F FULLWIDTH SOLIDUS maps to U+002F SOLIDUS.
        XCTAssertNil(IDNA.toAscii("a\u{FF0F}b.com"))
        // U+FF20 FULLWIDTH COMMERCIAL AT maps to U+0040 COMMERCIAL AT.
        XCTAssertNil(IDNA.toAscii("a\u{FF20}b.com"))
    }

    /// With STD3 off, non-LDH ASCII passes through unchanged. Useful for
    /// callers that want UTS #46 mapping/normalization without LDH gating
    /// (e.g. testing infrastructure, hostnames containing `_`).
    func testToAsciiAcceptsNonLDHASCIIWithoutSTD3() {
        let opts = IDNA.Options(useSTD3ASCIIRules: false)
        XCTAssertEqual(IDNA.toAscii("a_b.com", options: opts), "a_b.com")
        XCTAssertEqual(IDNA.toAscii("a/b.com", options: opts), "a/b.com")
        XCTAssertEqual(IDNA.toAscii("a:b.com", options: opts), "a:b.com")
    }

    /// STD3 must also fire after Punycode-decoding an `xn--` label whose
    /// decoded U-label contains non-LDH ASCII.
    func testToAsciiRejectsXNDecodedNonLDHWithSTD3() {
        // Encode "a_b" via Punycode → get the ACE form, then assert STD3
        // rejects the resulting label after decode/revalidate.
        guard let body = Punycode.encode("a_b") else {
            return XCTFail("Punycode.encode(\"a_b\") returned nil")
        }
        let ace = "xn--" + body
        XCTAssertNil(IDNA.toAscii("\(ace).com"))
        // Same input should pass with STD3 off.
        let opts = IDNA.Options(useSTD3ASCIIRules: false)
        XCTAssertNotNil(IDNA.toAscii("\(ace).com", options: opts))
    }

    /// Hyphen, digits, lowercase letters — the LDH set — must continue
    /// to round-trip cleanly with STD3 on.
    func testToAsciiAcceptsLDHWithSTD3() {
        XCTAssertEqual(IDNA.toAscii("a-b-c.example"), "a-b-c.example")
        XCTAssertEqual(IDNA.toAscii("abc123.example"), "abc123.example")
    }

    func testToAsciiDropsIgnoredScalars() {
        // U+00AD SOFT HYPHEN is `ignored`.
        XCTAssertEqual(IDNA.toAscii("ex\u{00AD}ample.com"), "example.com")
    }

    func testToAsciiRejectsInvalidPunycode() {
        XCTAssertNil(IDNA.toAscii("xn--***.com"))
    }

    func testToAsciiRejects63OctetCap() {
        // Construct a label whose ACE form exceeds 63 octets.
        let huge = String(repeating: "ñ", count: 60)
        XCTAssertNil(IDNA.toAscii("\(huge).com"))
    }

    // MARK: - ToUnicode

    func testToUnicodeDecodesACELabel() {
        XCTAssertEqual(IDNA.toUnicode("xn--mnchen-3ya.de"), "münchen.de")
        XCTAssertEqual(IDNA.toUnicode("xn--wgv71a.jp"), "日本.jp")
    }

    func testToUnicodeFoldsCaseAndFullwidth() {
        XCTAssertEqual(IDNA.toUnicode("EXAMPLE.COM"), "example.com")
        XCTAssertEqual(IDNA.toUnicode("ｅｘａｍｐｌｅ\u{FF0E}ｃｏｍ"), "example.com")
    }

    // MARK: - Empty / boundary

    func testToAsciiEmptyString() {
        // Empty input has zero labels and would yield empty output. Per
        // RFC 5891 / SMTP, an empty domain is not deliverable — but UTS #46
        // step 4 doesn't itself reject it. We mirror the spec; downstream
        // base validators (TLDDomainValidator) reject empty.
        XCTAssertEqual(IDNA.toAscii(""), "")
    }

    func testToAsciiSingleLabelOK() {
        // UTS #46 doesn't require ≥2 labels — that's an SMTP-layer rule.
        XCTAssertEqual(IDNA.toAscii("localhost"), "localhost")
    }
}
