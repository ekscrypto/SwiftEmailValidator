//
//  MixedScriptTests.swift
//  SwiftEmailValidatorUTS39Tests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//

import XCTest
@testable import SwiftEmailValidatorUTS39

final class MixedScriptTests: XCTestCase {

    private let highly = UTS39.Policy(
        level: .highlyRestrictive,
        rejectRestrictedIdentifiers: true)

    private let single = UTS39.Policy(
        level: .singleScript,
        rejectRestrictedIdentifiers: true)

    private let moderate = UTS39.Policy(
        level: .moderatelyRestrictive,
        rejectRestrictedIdentifiers: true)

    // MARK: - Single-script happy paths

    func testPureLatinSingleScriptPasses() {
        XCTAssertTrue(UTS39.evaluate("hello", policy: single))
        XCTAssertTrue(UTS39.evaluate("first.last", policy: single))
    }

    func testPureCyrillicSingleScriptPasses() {
        XCTAssertTrue(UTS39.evaluate("привет", policy: single))
    }

    func testPureGreekSingleScriptPasses() {
        XCTAssertTrue(UTS39.evaluate("γειά", policy: single))
    }

    func testDigitsAndPunctuationAreCommonAndPassEverywhere() {
        // Digits, hyphen, dot are Common; they should never contribute to
        // mixed-script classification.
        XCTAssertTrue(UTS39.evaluate("123.456", policy: single))
        XCTAssertTrue(UTS39.evaluate("user-42", policy: single))
    }

    // MARK: - Classic homograph attacks

    func testLatinCyrillicHomographRejected() {
        // "pаypal" with Cyrillic а (U+0430) replacing Latin a.
        let spoof = "p\u{0430}ypal"
        XCTAssertFalse(UTS39.evaluate(spoof, policy: highly))
        XCTAssertFalse(UTS39.evaluate(spoof, policy: single))
        XCTAssertFalse(UTS39.evaluate(spoof, policy: moderate),
                       "Moderately Restrictive still rejects Latin+Cyrillic per UTS #39 §5.2 (Moderately Restrictive bullet)")
    }

    func testLatinGreekHomographRejected() {
        // "gοοgle" with Greek omicron (U+03BF) replacing Latin o.
        let spoof = "g\u{03BF}\u{03BF}gle"
        XCTAssertFalse(UTS39.evaluate(spoof, policy: highly))
        XCTAssertFalse(UTS39.evaluate(spoof, policy: moderate),
                       "Moderately Restrictive rejects Latin+Greek per UTS #39 §5.2 (Moderately Restrictive bullet)")
    }

    // MARK: - Highly Restrictive multi-script whitelist

    func testJapaneseMixLatinHanHiraganaKatakana() {
        // "ABC会社カナひら" — Latin + Han + Katakana + Hiragana.
        XCTAssertTrue(UTS39.evaluate("ABC会社カナひら", policy: highly))
    }

    func testKoreanMixLatinHanHangul() {
        // Latin + Han + Hangul — allowed per Highly Restrictive.
        XCTAssertTrue(UTS39.evaluate("user가나", policy: highly))
        XCTAssertTrue(UTS39.evaluate("user漢가나", policy: highly))
    }

    func testChineseMixLatinHan() {
        XCTAssertTrue(UTS39.evaluate("user中文", policy: highly))
    }

    // MARK: - Single Script rejection of whitelisted combos

    func testSingleScriptRejectsJapaneseMix() {
        // Single Script is stricter than Highly Restrictive — adding Latin
        // breaks the augmented-set intersection (Latn doesn't fold into Jpan),
        // so Latin + Han + Hiragana + Katakana is NOT single-script.
        XCTAssertFalse(UTS39.evaluate("ABC会社カナひら", policy: single))
    }

    // MARK: - UTS #39 §5.1 Augmented Script Set behavior

    func testSingleScriptAcceptsPureJapaneseHanAndHiraganaAndKatakana() {
        // Per UTS #39 §5.1, Hani folds to {Hanb, Jpan, Kore} and Hira/Kana
        // fold to Jpan, so Han + Hira + Kana share Jpan in the augmented
        // intersection — it IS Single Script. Without §5.1 augmentation the
        // raw Script_Extensions don't intersect and this would be wrongly
        // rejected.
        XCTAssertTrue(UTS39.evaluate("会社カナひら", policy: single))
    }

    func testSingleScriptAcceptsPureKoreanHanAndHangul() {
        // Han ({Hanb, Jpan, Kore}) ∩ Hang ({Kore}) = {Kore} → Single Script.
        XCTAssertTrue(UTS39.evaluate("漢가나", policy: single))
    }

    func testSingleScriptAcceptsPureChineseHanAndBopomofo() {
        // Han ({Hanb, Jpan, Kore}) ∩ Bopo ({Hanb}) = {Hanb} → Single Script.
        // Bopomofo letters (U+3105+) are UTS #39 Identifier_Status=Restricted,
        // so this test must opt out of the restricted check to isolate the
        // §5.1 augmented-set behavior.
        let policy = UTS39.Policy(level: .singleScript, rejectRestrictedIdentifiers: false)
        XCTAssertTrue(UTS39.evaluate("中ㄅㄆㄇ", policy: policy))
    }

    func testSingleScriptRejectsHiraganaPlusHangul() {
        // Hira ({Hira, Jpan}) ∩ Hang ({Hang, Kore}) = ∅ → not Single Script,
        // even with §5.1 augmentation. Pins that the §5.1 closure doesn't
        // accidentally bridge unrelated CJK syllabaries.
        XCTAssertFalse(UTS39.evaluate("ひら가나", policy: single))
    }

    func testSingleScriptRejectsBopomofoPlusHiragana() {
        // Bopo ({Bopo, Hanb}) ∩ Hira ({Hira, Jpan}) = ∅. Bypasses the
        // Identifier_Status=Restricted check on Bopomofo letters to keep the
        // assertion focused on the §5.1 augmented-set behavior.
        let policy = UTS39.Policy(level: .singleScript, rejectRestrictedIdentifiers: false)
        XCTAssertFalse(UTS39.evaluate("ㄅㄆひら", policy: policy))
    }

    // MARK: - Moderately Restrictive

    func testModeratelyRestrictiveAllowsLatinPlusOneOther() {
        // Latin + Arabic — acceptable under Moderately Restrictive
        // (but Cyrillic and Greek are still rejected).
        XCTAssertTrue(UTS39.evaluate("userشيء", policy: moderate))
    }

    func testModeratelyRestrictiveRejectsThreeScripts() {
        // Latin + Arabic + Hebrew — too many scripts.
        XCTAssertFalse(UTS39.evaluate("userشא", policy: moderate))
    }
}
