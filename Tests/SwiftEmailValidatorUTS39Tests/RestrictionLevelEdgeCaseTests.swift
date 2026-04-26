//
//  RestrictionLevelEdgeCaseTests.swift
//  SwiftEmailValidatorUTS39Tests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Boundary cases for UTS #39 §5.2 Restriction Level classification,
//  inspired by ICU's `icu4c/source/test/intltest/itspoof.cpp` and the
//  specification's own §5.2 examples. These probe the edges of the
//  Common/Inherited handling, the Highly Restrictive whitelist, and the
//  Moderately Restrictive Latin+other rule.
//

import XCTest
@testable import SwiftEmailValidatorUTS39

final class RestrictionLevelEdgeCaseTests: XCTestCase {

    private let singleScript = UTS39.Policy(
        level: .singleScript,
        rejectRestrictedIdentifiers: false)
    private let highlyRestrictive = UTS39.Policy(
        level: .highlyRestrictive,
        rejectRestrictedIdentifiers: false)
    private let moderatelyRestrictive = UTS39.Policy(
        level: .moderatelyRestrictive,
        rejectRestrictedIdentifiers: false)

    // MARK: - Common / Inherited handling (§5.2 note on wildcards)

    func testDigitsOnlyPassesEveryLevel() {
        // ASCII digits are Common; no script constraint.
        XCTAssertTrue(UTS39.evaluate("0123456789", policy: singleScript))
        XCTAssertTrue(UTS39.evaluate("0123456789", policy: highlyRestrictive))
        XCTAssertTrue(UTS39.evaluate("0123456789", policy: moderatelyRestrictive))
    }

    func testPunctuationOnlyPassesEveryLevel() {
        // Hyphens, dots, underscores are Common.
        XCTAssertTrue(UTS39.evaluate("-._", policy: singleScript))
    }

    func testCombiningMarksOnlyVacuouslyPass() {
        // Pure combining marks (Inherited only) — vacuously single-script.
        // U+0301 COMBINING ACUTE ACCENT, U+0303 COMBINING TILDE.
        XCTAssertTrue(UTS39.evaluate("\u{0301}\u{0303}", policy: singleScript))
    }

    func testLatinPlusCombiningMarkStaysSingleScript() {
        // é = e + U+0301 (Inherited). Must not force multi-script classification.
        XCTAssertTrue(UTS39.evaluate("na\u{0301}ive", policy: singleScript))
    }

    func testLatinPlusDigitsStaysSingleScript() {
        XCTAssertTrue(UTS39.evaluate("alice42", policy: singleScript))
    }

    // MARK: - Highly Restrictive whitelist

    func testHanAloneIsSingleScript() {
        XCTAssertTrue(UTS39.evaluate("漢字", policy: singleScript))
    }

    func testHiraganaAloneIsSingleScript() {
        XCTAssertTrue(UTS39.evaluate("ひらがな", policy: singleScript))
    }

    func testHiraganaPlusKatakanaIsSingleScriptUnderAugmentedRule() {
        // Per UTS #39 §5.1, Hira folds to Jpan and Kana folds to Jpan, so
        // Hira + Kana intersect at {Jpan} — Single Script (Japanese). Was a
        // subset of the Highly Restrictive Japanese combo before the §5.1
        // fix; still passes Highly Restrictive (which subsumes Single Script).
        XCTAssertTrue(UTS39.evaluate("あアいイ", policy: singleScript))
        XCTAssertTrue(UTS39.evaluate("あアいイ", policy: highlyRestrictive))
    }

    func testLatinPlusHanIsHighlyRestrictive() {
        XCTAssertTrue(UTS39.evaluate("user漢", policy: highlyRestrictive))
    }

    func testLatinPlusHangulWithoutHanIsHighlyRestrictive() {
        // {Latn, Hang} is a subset of the Korean combo {Latn, Hani, Hang}
        // per UTS #39 §5.2 (Highly Restrictive bullet) — subsets of whitelisted combos also pass.
        XCTAssertTrue(UTS39.evaluate("user가", policy: highlyRestrictive))
    }

    func testLatinPlusHangulPlusHanIsHighlyRestrictive() {
        XCTAssertTrue(UTS39.evaluate("user漢가", policy: highlyRestrictive))
    }

    func testLatinPlusHiraganaWithoutHanIsHighlyRestrictive() {
        // Subset of Japanese combo {Latn, Hani, Hira, Kana}.
        XCTAssertTrue(UTS39.evaluate("userあ", policy: highlyRestrictive))
    }

    func testLatinPlusBopomofoIsHighlyRestrictive() {
        // ㄅ U+3105 BOPOMOFO LETTER B.
        XCTAssertTrue(UTS39.evaluate("user\u{3105}", policy: highlyRestrictive))
    }

    func testLatinPlusHanPlusBopomofoIsHighlyRestrictive() {
        XCTAssertTrue(UTS39.evaluate("user漢\u{3105}", policy: highlyRestrictive))
    }

    // MARK: - Rejected combinations

    func testLatinPlusCyrillicRejectedAtEveryLevel() {
        // Latin + Cyrillic is the canonical homograph vector; UTS #39 §5.2
        // (Moderately Restrictive bullet) calls it out as excluded even at
        // that level.
        let spoof = "user\u{0430}lice" // Cyrillic а
        XCTAssertFalse(UTS39.evaluate(spoof, policy: singleScript))
        XCTAssertFalse(UTS39.evaluate(spoof, policy: highlyRestrictive))
        XCTAssertFalse(UTS39.evaluate(spoof, policy: moderatelyRestrictive))
    }

    func testLatinPlusGreekRejectedAtEveryLevel() {
        let spoof = "user\u{03B1}lpha" // Greek alpha
        XCTAssertFalse(UTS39.evaluate(spoof, policy: singleScript))
        XCTAssertFalse(UTS39.evaluate(spoof, policy: highlyRestrictive))
        XCTAssertFalse(UTS39.evaluate(spoof, policy: moderatelyRestrictive))
    }

    func testThreeScriptsFailsHighlyRestrictive() {
        // Latin + Han + Arabic — Arabic breaks the whitelist; no Japanese/
        // Korean/Chinese combo includes Arabic.
        XCTAssertFalse(UTS39.evaluate("user漢\u{0634}", policy: highlyRestrictive))
    }

    // MARK: - Moderately Restrictive — Latin + one other

    func testLatinPlusArabicPassesModeratelyRestrictive() {
        XCTAssertTrue(UTS39.evaluate("user\u{0634}\u{0635}", policy: moderatelyRestrictive))
    }

    func testLatinPlusHebrewPassesModeratelyRestrictive() {
        XCTAssertTrue(UTS39.evaluate("user\u{05D0}\u{05D1}", policy: moderatelyRestrictive))
    }

    func testLatinPlusDevanagariPassesModeratelyRestrictive() {
        XCTAssertTrue(UTS39.evaluate("user\u{0905}\u{0906}", policy: moderatelyRestrictive))
    }

    func testThreeNonLatinScriptsFailsModeratelyRestrictive() {
        // Arabic + Hebrew + Devanagari (no Latin) — three scripts, no combo.
        XCTAssertFalse(UTS39.evaluate("\u{0634}\u{05D0}\u{0905}", policy: moderatelyRestrictive))
    }

    func testLatinPlusNonRecommendedScriptFailsModeratelyRestrictive() {
        // Phoenician (U+10900..U+1091B) is Identifier_Status=Restricted and is
        // NOT a UAX #31 Recommended script. Even with the Restricted gate
        // disabled, Moderately Restrictive must reject Latin + Phoenician
        // because the second script is not in the Recommended candidate pool.
        // U+10900 PHOENICIAN LETTER ALF.
        XCTAssertFalse(UTS39.evaluate("user\u{10900}\u{10901}", policy: moderatelyRestrictive))
    }

    func testLatinPlusLimbuFailsModeratelyRestrictive() {
        // Limbu (U+1900..U+194F) is Identifier_Status=Restricted and not a
        // UAX #31 Recommended script. Same lenient-mode reasoning as above.
        // U+1900 LIMBU VOWEL-CARRIER LETTER.
        XCTAssertFalse(UTS39.evaluate("user\u{1900}\u{1901}", policy: moderatelyRestrictive))
    }

    func testNonLatinSingleScriptPassesModeratelyRestrictive() {
        // Pure Arabic is single-script, passes Moderately Restrictive
        // (Moderately permits ≤ Highly which permits Single).
        XCTAssertTrue(UTS39.evaluate("\u{0634}\u{0635}\u{0636}", policy: moderatelyRestrictive))
    }

    // MARK: - Arabic/Devanagari digit mixing (§5.3 companion concern)

    func testAsciiDigitsMixedWithArabicScriptRejectsAtSingleScript() {
        // Arabic script letters + ASCII digits. ASCII digits are Common and
        // should not constrain the script — so the label counts as pure
        // Arabic (single script).
        XCTAssertTrue(UTS39.evaluate("\u{0634}\u{0635}123", policy: singleScript))
    }

    func testArabicIndicDigitsMixedWithLatinIsMultiScript() {
        // U+0660 ARABIC-INDIC DIGIT ZERO is in Script=Arab, NOT Common.
        // Therefore Latin + Arabic-Indic digit forms a multi-script string.
        XCTAssertFalse(UTS39.evaluate("user\u{0660}\u{0661}", policy: singleScript))
        // Passes Moderately Restrictive (Latin + one other, Arabic allowed).
        XCTAssertTrue(UTS39.evaluate("user\u{0660}\u{0661}", policy: moderatelyRestrictive))
    }

    // MARK: - Degenerate inputs

    func testSingleCharacterStringsAlwaysPass() {
        XCTAssertTrue(UTS39.evaluate("a", policy: singleScript))
        XCTAssertTrue(UTS39.evaluate("\u{0430}", policy: singleScript))
        XCTAssertTrue(UTS39.evaluate("漢", policy: singleScript))
    }

    func testEmptyStringPasses() {
        // Vacuously — no scalars means no script constraint.
        XCTAssertTrue(UTS39.evaluate("", policy: singleScript))
    }

    // MARK: - Whole-script confusable (skeleton-level)

    func testCyrillicWholeScriptConfusableWithoutConfusablesPolicyPasses() {
        // Pure Cyrillic string [а, о, е] (U+0430, U+043E, U+0435) whose
        // skeleton matches Latin "aoe". Without rejectConfusables it passes
        // — pure Cyrillic is single-script.
        XCTAssertTrue(UTS39.evaluate("\u{0430}\u{043E}\u{0435}", policy: singleScript))
    }

    func testCyrillicWholeScriptConfusableFailsWhenConfusablesPolicyEnabled() {
        let policy = UTS39.Policy(
            level: .singleScript,
            rejectRestrictedIdentifiers: false,
            rejectConfusables: true,
            confusableSkeletons: ["aoe"])
        XCTAssertFalse(UTS39.evaluate("\u{0430}\u{043E}\u{0435}", policy: policy))
    }
}
