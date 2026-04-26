//
//  ContextOTests.swift
//  SwiftEmailValidatorIDNATests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Focused unit tests for RFC 5892 §A.3-§A.9 CONTEXTO rules. UTS #46
//  IdnaTestV2 vectors do not exercise these — CONTEXTO is layered on
//  top of UTS #46 as a security extension and the conformance driver
//  runs with `checkContextO: false`. These tests pin down acceptance
//  and rejection on small, hand-built inputs per rule.
//

import XCTest
@testable import SwiftEmailValidatorIDNA

final class ContextOTests: XCTestCase {

    // MARK: - §A.3 MIDDLE DOT (U+00B7) — between two 'l'

    func testMiddleDotBetweenLAccepted() {
        // Catalan ela geminada: "l·l" → "paral·lel".
        XCTAssertNotNil(IDNA.toAscii("para\u{006C}\u{00B7}\u{006C}el.example"))
    }

    func testMiddleDotBetweenNonLRejected() {
        // U+00B7 between 'a' and 'b' — not flanked by 'l'.
        XCTAssertNil(IDNA.toAscii("a\u{00B7}b.example"))
    }

    func testMiddleDotAtLabelStartRejected() {
        XCTAssertNil(IDNA.toAscii("\u{00B7}llel.example"))
    }

    func testMiddleDotAtLabelEndRejected() {
        XCTAssertNil(IDNA.toAscii("paral\u{00B7}.example"))
    }

    func testMiddleDotOnlyOneSideLRejected() {
        // Right neighbor 'l' but left neighbor 'a' — fails.
        XCTAssertNil(IDNA.toAscii("a\u{00B7}lel.example"))
    }

    // MARK: - §A.4 GREEK KERAIA (U+0375) — followed by Greek

    func testGreekKeraiaFollowedByGreekAccepted() {
        // U+0375 GREEK LOWER NUMERAL SIGN followed by U+03B1 GREEK
        // SMALL LETTER ALPHA.
        XCTAssertNotNil(IDNA.toAscii("\u{03B2}\u{0375}\u{03B1}.example"))
    }

    func testGreekKeraiaFollowedByLatinRejected() {
        XCTAssertNil(IDNA.toAscii("\u{03B2}\u{0375}a.example"))
    }

    func testGreekKeraiaAtLabelEndRejected() {
        // No "after" scalar.
        XCTAssertNil(IDNA.toAscii("\u{03B2}\u{0375}.example"))
    }

    // MARK: - §A.5 / §A.6 HEBREW GERESH / GERSHAYIM — preceded by Hebrew

    func testHebrewGereshAfterHebrewAccepted() {
        // U+05D0 HEBREW LETTER ALEF + U+05F3 GERESH.
        XCTAssertNotNil(IDNA.toAscii("\u{05D0}\u{05F3}.example"))
    }

    func testHebrewGereshAfterLatinRejected() {
        XCTAssertNil(IDNA.toAscii("a\u{05F3}.example"))
    }

    func testHebrewGereshAtLabelStartRejected() {
        XCTAssertNil(IDNA.toAscii("\u{05F3}\u{05D0}.example"))
    }

    func testHebrewGershayimAfterHebrewAccepted() {
        // U+05D1 HEBREW LETTER BET + U+05F4 GERSHAYIM.
        XCTAssertNotNil(IDNA.toAscii("\u{05D1}\u{05F4}.example"))
    }

    func testHebrewGershayimAfterLatinRejected() {
        XCTAssertNil(IDNA.toAscii("a\u{05F4}.example"))
    }

    // MARK: - §A.7 KATAKANA MIDDLE DOT (U+30FB) — label has Hiragana/Katakana/Han

    func testKatakanaMiddleDotWithKatakanaAccepted() {
        // U+30A2 KATAKANA LETTER A satisfies the rule.
        XCTAssertNotNil(IDNA.toAscii("\u{30A2}\u{30FB}\u{30A4}.example"))
    }

    func testKatakanaMiddleDotWithHiraganaAccepted() {
        // U+3042 HIRAGANA LETTER A satisfies the rule.
        XCTAssertNotNil(IDNA.toAscii("\u{3042}\u{30FB}\u{3044}.example"))
    }

    func testKatakanaMiddleDotWithHanAccepted() {
        // U+4E2D (中) is Han.
        XCTAssertNotNil(IDNA.toAscii("\u{4E2D}\u{30FB}\u{56FD}.example"))
    }

    func testKatakanaMiddleDotWithoutCJKRejected() {
        // Latin-only label with U+30FB → no Hiragana/Katakana/Han present.
        XCTAssertNil(IDNA.toAscii("a\u{30FB}b.example"))
    }

    // MARK: - §A.8 / §A.9 ARABIC-INDIC vs EXTENDED ARABIC-INDIC mixing

    func testArabicIndicDigitsAloneAccepted() {
        // U+0660..U+0669 alone (mixed with Arabic letters for a valid label).
        XCTAssertNotNil(IDNA.toAscii("\u{0627}\u{0660}\u{0661}.example"))
    }

    func testExtendedArabicIndicDigitsAloneAccepted() {
        // U+06F0..U+06F9 alone.
        XCTAssertNotNil(IDNA.toAscii("\u{0627}\u{06F0}\u{06F1}.example"))
    }

    func testMixingArabicIndicDigitFamiliesRejected() {
        // U+0660 (Arabic-Indic) + U+06F0 (Extended Arabic-Indic) in the
        // same label.
        XCTAssertNil(IDNA.toAscii("\u{0627}\u{0660}\u{06F0}.example"))
    }

    func testMixingDigitFamiliesAcrossLabelsAccepted() {
        // Mixing across labels is fine — §A.8/§A.9 are per-label.
        XCTAssertNotNil(IDNA.toAscii("\u{0627}\u{0660}.\u{0627}\u{06F0}.example"))
    }

    // MARK: - Opt-out: checkContextO: false accepts violations

    func testCheckContextOOffAcceptsMiddleDotViolation() {
        let opts = IDNA.Options(checkContextO: false)
        XCTAssertNotNil(IDNA.toAscii("a\u{00B7}b.example", options: opts))
    }

    func testCheckContextOOffAcceptsGreekKeraiaViolation() {
        let opts = IDNA.Options(checkContextO: false)
        XCTAssertNotNil(IDNA.toAscii("\u{03B2}\u{0375}a.example", options: opts))
    }

    func testCheckContextOOffAcceptsHebrewGereshViolation() {
        // "a\u{05F3}" mixes L and R — also fails CheckBidi. To isolate
        // the CONTEXTO opt-out, disable Bidi too.
        let opts = IDNA.Options(checkBidi: false, checkContextO: false)
        XCTAssertNotNil(IDNA.toAscii("a\u{05F3}.example", options: opts))
    }

    func testCheckContextOOffAcceptsKatakanaMiddleDotViolation() {
        let opts = IDNA.Options(checkContextO: false)
        XCTAssertNotNil(IDNA.toAscii("a\u{30FB}b.example", options: opts))
    }

    func testCheckContextOOffAcceptsMixedDigitFamilies() {
        // U+0660 (AN) and U+06F0 (EN) in the same RTL label also violates
        // the RFC 5893 §2 condition 4 EN/AN exclusion — disable Bidi to
        // isolate the CONTEXTO opt-out.
        let opts = IDNA.Options(checkBidi: false, checkContextO: false)
        XCTAssertNotNil(IDNA.toAscii("\u{0627}\u{0660}\u{06F0}.example", options: opts))
    }

    // MARK: - Default options enable CONTEXTO

    func testDefaultOptionsEnableCheckContextO() {
        XCTAssertTrue(IDNA.Options().checkContextO)
    }

    // MARK: - Script lookup smoke tests

    func testScriptLookupKnownScalars() {
        // U+03B1 GREEK SMALL LETTER ALPHA → Greek.
        XCTAssertEqual(ScriptLookup.category(of: 0x03B1), .greek)
        // U+05D0 HEBREW LETTER ALEF → Hebrew.
        XCTAssertEqual(ScriptLookup.category(of: 0x05D0), .hebrew)
        // U+3042 HIRAGANA LETTER A → Hiragana.
        XCTAssertEqual(ScriptLookup.category(of: 0x3042), .hiragana)
        // U+30A2 KATAKANA LETTER A → Katakana.
        XCTAssertEqual(ScriptLookup.category(of: 0x30A2), .katakana)
        // U+4E2D CJK Unified Ideograph 中 → Han.
        XCTAssertEqual(ScriptLookup.category(of: 0x4E2D), .han)
    }

    func testScriptLookupOtherForLatinAndCommon() {
        // U+0061 'a' Latin → other (not tracked).
        XCTAssertEqual(ScriptLookup.category(of: 0x0061), .other)
        // U+30FB KATAKANA MIDDLE DOT — script Common, *not* Katakana —
        // this is the explicit RFC 5892 §A.7 note.
        XCTAssertEqual(ScriptLookup.category(of: 0x30FB), .other)
    }
}
