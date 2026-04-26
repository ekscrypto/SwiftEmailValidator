//
//  ContextJTests.swift
//  SwiftEmailValidatorIDNATests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Focused unit tests for RFC 5892 §A.1 (ZWNJ) and §A.2 (ZWJ). The
//  conformance driver covers cross-cutting cases via [Cn] vectors; the
//  cases here pin down acceptance and rejection on small, hand-built
//  inputs for clearer regression triage.
//

import XCTest
@testable import SwiftEmailValidatorIDNA

final class ContextJTests: XCTestCase {

    // MARK: - ZWJ (U+200D) §A.2: must follow a Virama

    func testZWJAfterDevanagariViramaAccepted() {
        // U+0915 KA (Joining_Type=U, generalCategory Lo) +
        // U+094D VIRAMA (CCC=9) +
        // U+200D ZWJ +
        // U+0937 SSA — a real Devanagari conjunct example "क्\u{200D}ष".
        XCTAssertNotNil(IDNA.toAscii("\u{0915}\u{094D}\u{200D}\u{0937}.example"),
                        "ZWJ preceded by Virama is required for Indic conjuncts and must be accepted.")
    }

    func testZWJWithoutPrecedingViramaRejected() {
        // ZWJ between two Latin letters with no Virama → §A.2 fails.
        XCTAssertNil(IDNA.toAscii("a\u{200D}b.example"))
    }

    func testZWJAtLabelStartRejected() {
        // No preceding scalar → §A.2 fails.
        XCTAssertNil(IDNA.toAscii("\u{200D}abc.example"))
    }

    // MARK: - ZWNJ (U+200C) §A.1: Virama OR joining-context regex

    func testZWNJAfterDevanagariViramaAccepted() {
        // Same shape as ZWJ test — Virama predecessor accepts ZWNJ too.
        XCTAssertNotNil(IDNA.toAscii("\u{0915}\u{094D}\u{200C}\u{0937}.example"))
    }

    func testZWNJBetweenJoiningArabicAccepted() {
        // U+0628 BEH (Joining_Type=D) + U+200C ZWNJ + U+064A YEH (D).
        // Persian uses ZWNJ between joining letters.
        XCTAssertNotNil(IDNA.toAscii("\u{0628}\u{200C}\u{064A}.example"))
    }

    func testZWNJBetweenLatinLettersRejected() {
        // No Virama, no joining-type {L,D}/{R,D} on either side. §A.1 fails.
        XCTAssertNil(IDNA.toAscii("a\u{200C}b.example"))
    }

    func testZWNJAtLabelStartRejected() {
        XCTAssertNil(IDNA.toAscii("\u{200C}abc.example"))
    }

    func testZWNJAtLabelEndRejected() {
        XCTAssertNil(IDNA.toAscii("abc\u{200C}.example"))
    }

    // MARK: - Multiple ZWJ/ZWNJ — any single failure rejects

    func testFirstValidSecondInvalidRejected() {
        // First ZWJ correctly preceded by Virama, second ZWJ between Latin
        // letters → second occurrence fails the rule.
        XCTAssertNil(IDNA.toAscii("\u{0915}\u{094D}\u{200D}a\u{200D}b.example"))
    }

    // MARK: - Opt-out: CheckJoiners off accepts violations

    func testCheckJoinersOffAcceptsZWJViolation() {
        let opts = IDNA.Options(checkJoiners: false)
        // Without CONTEXTJ, a\u{200D}b passes label validation (ZWJ is
        // `deviation` in nontransitional, kept as-is) and Punycode-encodes.
        XCTAssertNotNil(IDNA.toAscii("a\u{200D}b.example", options: opts))
    }

    func testCheckJoinersOffAcceptsZWNJViolation() {
        let opts = IDNA.Options(checkJoiners: false)
        XCTAssertNotNil(IDNA.toAscii("a\u{200C}b.example", options: opts))
    }

    // MARK: - Lookups

    func testViramaLookupKnownDevanagariVirama() {
        // U+094D DEVANAGARI SIGN VIRAMA, CCC=9.
        XCTAssertTrue(ViramaLookup.isVirama(0x094D))
    }

    func testViramaLookupKnownNonVirama() {
        // U+0915 DEVANAGARI LETTER KA, CCC=0.
        XCTAssertFalse(ViramaLookup.isVirama(0x0915))
        // U+0061 'a', CCC=0.
        XCTAssertFalse(ViramaLookup.isVirama(0x0061))
    }

    func testJoiningTypeKnownClasses() {
        // U+0628 BEH = D
        XCTAssertEqual(JoiningTypeLookup.category(of: 0x0628), .D)
        // U+0627 ALEF = R
        XCTAssertEqual(JoiningTypeLookup.category(of: 0x0627), .R)
        // U+200D ZWJ = C
        XCTAssertEqual(JoiningTypeLookup.category(of: 0x200D), .C)
        // U+0061 'a' = U (default)
        XCTAssertEqual(JoiningTypeLookup.category(of: 0x0061), .U)
    }
}
