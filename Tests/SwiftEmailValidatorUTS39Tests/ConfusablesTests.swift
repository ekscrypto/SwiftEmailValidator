//
//  ConfusablesTests.swift
//  SwiftEmailValidatorUTS39Tests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//

import XCTest
@testable import SwiftEmailValidatorUTS39

final class ConfusablesTests: XCTestCase {

    // MARK: - Skeleton computation

    func testSkeletonCollapsesCyrillicSpoofToLatinForm() {
        // Idempotence is exhaustively covered by
        // ConfusablesSkeletonRegressionTests.testSkeletonIsIdempotent over
        // every confusable source codepoint, so re-pinning it here added no
        // signal. Replace with the load-bearing UTS #39 §4 property: the
        // skeleton operation must collapse a confusable spoof to the same
        // string as its target. If the table is mis-loaded or the mapping
        // is dropped, this assertion fails immediately.
        let latin = "paypal"
        let spoof = "p\u{0430}ypal" // Cyrillic 'а' in position 1
        XCTAssertNotEqual(latin, spoof, "pre-condition: strings differ at the scalar level")
        XCTAssertEqual(ConfusableSkeleton.skeleton(of: latin),
                       ConfusableSkeleton.skeleton(of: spoof),
                       "Latin paypal and Cyrillic-а spoof must skeleton to the same form (UTS #39 §4)")
    }

    func testCyrillicSpoofIsConfusableWithLatin() {
        // Classic: Cyrillic 'а' (U+0430) skeleton === Latin 'a' skeleton.
        let latin = "paypal"
        let spoof = "p\u{0430}yp\u{0430}l"
        XCTAssertNotEqual(latin, spoof, "pre-condition: strings differ")
        XCTAssertTrue(
            ConfusableSkeleton.areConfusable(latin, spoof),
            "Latin paypal and Cyrillic-a variant should be confusables")
    }

    func testGreekOmicronConfusableWithLatinO() {
        let latin = "google"
        let spoof = "g\u{03BF}\u{03BF}gle" // Greek omicron ×2
        XCTAssertTrue(ConfusableSkeleton.areConfusable(latin, spoof))
    }

    func testUnrelatedStringsAreNotConfusable() {
        XCTAssertFalse(ConfusableSkeleton.areConfusable("hello", "world"))
        XCTAssertFalse(ConfusableSkeleton.areConfusable("alice", "bob"))
    }

    // MARK: - Policy integration

    func testConfusablePolicyRejectsSkeletonClash() {
        let policy = UTS39.Policy(
            level: .singleScript,
            rejectRestrictedIdentifiers: false,
            rejectConfusables: true,
            confusableSkeletons: ["aoe"])

        // Pure Cyrillic string confusable with Latin "aoe".
        // а U+0430, о U+043E, е U+0435 — all Cyrillic.
        let spoof = "\u{0430}\u{043E}\u{0435}"
        XCTAssertFalse(UTS39.evaluate(spoof, policy: policy))
    }

    func testProtectedFormItselfIsAccepted() {
        let policy = UTS39.Policy(
            rejectConfusables: true,
            confusableSkeletons: ["paypal"])
        XCTAssertTrue(UTS39.evaluate("paypal", policy: policy))
    }

    func testAllowlistExemptsSpecificString() {
        // Pure Cyrillic string confusable with Latin "aoe" — single-script, so
        // mixed-script analysis passes; allowlist should then exempt it from
        // confusable rejection.
        let spoof = "\u{0430}\u{043E}\u{0435}"
        let policy = UTS39.Policy(
            level: .singleScript,
            rejectRestrictedIdentifiers: false,
            rejectConfusables: true,
            confusableSkeletons: ["aoe"],
            confusableAllowlist: [spoof])
        XCTAssertTrue(UTS39.evaluate(spoof, policy: policy))
    }

    func testConfusablesDisabledByDefault() {
        // Default policy does not reject the Latin-o → Greek-o spoof on
        // confusables grounds (though it does reject it on mixed-script
        // grounds because of Highly Restrictive). Force a pure-Greek form.
        let policy = UTS39.Policy() // defaults: level = .highlyRestrictive, rejectConfusables = false
        // All-Greek string — single-script so mixed-script passes; confusables
        // check is off, so it must pass.
        XCTAssertTrue(UTS39.evaluate("γειά", policy: policy))
    }
}
