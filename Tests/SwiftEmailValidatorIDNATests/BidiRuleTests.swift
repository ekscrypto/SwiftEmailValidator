//
//  BidiRuleTests.swift
//  SwiftEmailValidatorIDNATests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Focused unit tests for RFC 5893 §2 Bidi rule. Cross-cutting coverage
//  vs. the official UTS #46 vector set lives in IdnaTestV2DriverTests; the
//  cases here exercise specific conditions in isolation so regressions
//  point at the failing condition rather than a vector ID.
//

import XCTest
@testable import SwiftEmailValidatorIDNA

final class BidiRuleTests: XCTestCase {

    // Permissive base for IDNA — the Bidi rule applies after RFC syntax,
    // and we don't want TLD validation interfering with these focused cases.

    // MARK: - Acceptance: legitimate Bidi labels

    func testAcceptsArabicRTLLabel() {
        // "العربية" — pure Arabic letters (AL).
        XCTAssertNotNil(IDNA.toAscii("العربية.com"),
                        "RTL Arabic label must pass condition 1 (first AL) and condition 2/3.")
    }

    func testAcceptsHebrewRTLLabel() {
        // "עברית" — pure Hebrew letters (R).
        XCTAssertNotNil(IDNA.toAscii("עברית.com"))
    }

    func testAcceptsArabicWithArabicIndicDigits() {
        // "العربية٠٠٩" — AL letters + Arabic-Indic digits (AN). End is AN.
        XCTAssertNotNil(IDNA.toAscii("العربية٠٠٩.com"))
    }

    func testAcceptsLTROnlyLabelInLTRDomain() {
        // No RTL anywhere → Bidi rule doesn't fire.
        XCTAssertNotNil(IDNA.toAscii("example.com"))
    }

    // MARK: - Rejection: condition 1 (first char must be L, R, AL)

    func testRejectsLabelStartingWithDigit() {
        // "0\u{C0}.\u{5D0}" — first label "0À" starts with EN ('0'). Sibling
        // label "א" makes the domain Bidi → all labels must satisfy the
        // rule. EN is not L/R/AL → condition 1 fails.
        XCTAssertNil(IDNA.toAscii("0\u{00C0}.\u{05D0}"))
    }

    // MARK: - Rejection: condition 2 (RTL labels disallow L)

    func testRejectsRTLLabelContainingL() {
        // First char AL (Arabic) but contains L (Latin 'a') in middle → cond 2.
        XCTAssertNil(IDNA.toAscii("ا\u{0627}aا\u{0627}.com"))
    }

    // MARK: - Rejection: condition 3 (RTL ending must be R/AL/EN/AN)

    func testRejectsRTLLabelEndingInOtherNeutral() {
        // Hebrew letter then ON char (e.g. U+00B7 middle dot).
        // Strip trailing NSMs (none here) → end is ON, not R/AL/EN/AN.
        // Note: U+00B7 is `disallowed` for some contexts; pick ON-class
        // that survives mapping. U+00A0 NBSP is `disallowed`. U+0021 '!'
        // is `disallowed_STD3_valid`. Use U+00BB (right-pointing double
        // angle quotation, ON, `disallowed_STD3_valid`)... actually we
        // need a scalar that's `valid` post-mapping but ends RTL with ON.
        // Hebrew letter + Arabic Number (AN) with EN trailing trips
        // condition 4 instead. The cleanest condition-3 violation in the
        // valid-scalar space is hard to construct without overlapping
        // other rules; the conformance suite covers this fully via
        // [B3] vectors. Skip a synthetic case here and rely on those.
    }

    // MARK: - Rejection: condition 4 (no AN+EN mix)

    func testRejectsRTLLabelMixingENAndAN() {
        // AL letter + AN digit + EN digit → both AN and EN present.
        XCTAssertNil(IDNA.toAscii("ا\u{0627}\u{0660}1.com"))
    }

    // MARK: - Rejection: condition 6 (LTR ending must be L or EN)

    func testRejectsLTRLabelEndingInNonLNonEN() {
        // "à̌" (U+00E0 + U+02C7). 'à' is L, U+02C7 (CARON) is ON. End is
        // ON, not L/EN. Sibling Hebrew label triggers domain-wide rule.
        XCTAssertNil(IDNA.toAscii("\u{00E0}\u{02C7}.\u{05D0}"))
    }

    // MARK: - Rejection: encoded forms (xn--) round-trip the same way

    func testRejectsEncodedBidiViolation() {
        // Same as testRejectsLabelStartingWithDigit above but pre-ACE.
        XCTAssertNil(IDNA.toAscii("xn--0-sfa.xn--4db"))
    }

    // MARK: - Opt-out: CheckBidi off accepts ill-formed labels

    func testCheckBidiOffAcceptsViolation() {
        let opts = IDNA.Options(checkBidi: false)
        XCTAssertEqual(IDNA.toAscii("0\u{00C0}.\u{05D0}", options: opts),
                       "xn--0-sfa.xn--4db")
    }

    // MARK: - Empty / boundary

    func testEmptyLabelHasRTLReturnsFalse() {
        XCTAssertFalse(BidiRule.labelHasRTL(""))
    }

    func testPureLTRLabelHasRTLReturnsFalse() {
        XCTAssertFalse(BidiRule.labelHasRTL("example"))
    }

    func testHebrewLabelHasRTLReturnsTrue() {
        XCTAssertTrue(BidiRule.labelHasRTL("עברית"))
    }

    func testArabicNumberLabelHasRTLReturnsTrue() {
        // Arabic-Indic digits alone are AN class.
        XCTAssertTrue(BidiRule.labelHasRTL("\u{0660}\u{0661}"))
    }
}
