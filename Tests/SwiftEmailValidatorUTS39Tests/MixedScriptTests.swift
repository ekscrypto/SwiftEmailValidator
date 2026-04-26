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
        // Single Script is stricter than Highly Restrictive — the Latin + Han
        // + Hiragana + Katakana combo is NOT single-script.
        XCTAssertFalse(UTS39.evaluate("ABC会社カナひら", policy: single))
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
