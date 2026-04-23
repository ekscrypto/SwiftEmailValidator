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

    func testSkeletonOfLatinIdentity() {
        // ASCII strings should skeleton to themselves (or close to — some
        // ASCII scalars like 'I' map to themselves in confusables.txt; key
        // property: skeleton is deterministic and idempotent).
        let skeleton = ConfusableSkeleton.skeleton(of: "hello")
        XCTAssertEqual(skeleton, ConfusableSkeleton.skeleton(of: skeleton),
                       "skeleton should be idempotent")
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
