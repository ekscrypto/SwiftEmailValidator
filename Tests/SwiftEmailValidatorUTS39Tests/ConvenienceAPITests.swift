//
//  ConvenienceAPITests.swift
//  SwiftEmailValidatorUTS39Tests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//

import XCTest
@testable import SwiftEmailValidatorUTS39
import SwiftEmailValidator
import SwiftPublicSuffixList

final class ConvenienceAPITests: XCTestCase {

    /// PSL-bypass domain validator for tests that need to exercise the
    /// UTS #39 layer without depending on PSL rules. Any UTS #39 policy
    /// still applies to labels via the caller's explicit override.
    private let permissiveDomain: (String) -> Bool = { _ in true }

    // MARK: - correctlyFormatted(_:uts39:)

    func testCorrectlyFormattedAcceptsHealthyEmail() {
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "alice@example.com",
            uts39: UTS39.Policy(),
            domainValidator: permissiveDomain))
    }

    func testCorrectlyFormattedRejectsLatinCyrillicLocalPart() {
        // "p\u{0430}ypal" — Cyrillic а. Local-part mixed with Latin spoof.
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted(
            "p\u{0430}ypal@example.com",
            uts39: UTS39.Policy(),
            domainValidator: permissiveDomain))
    }

    func testCorrectlyFormattedRejectsSpoofedDomain() {
        // Healthy local part, spoofed domain label.
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted(
            "alice@p\u{0430}ypal.com",
            uts39: UTS39.Policy(),
            domainValidator: permissiveDomain))
    }

    func testCorrectlyFormattedAcceptsJapaneseLocal() {
        // Latin + Han + Katakana — passes Highly Restrictive.
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "user会社カナ@example.com",
            uts39: UTS39.Policy(),
            domainValidator: permissiveDomain))
    }

    // MARK: - mailbox(from:uts39:)

    func testMailboxReturnsMailboxOnSuccess() {
        let mailbox = EmailSyntaxValidator.mailbox(
            from: "alice@example.com",
            uts39: UTS39.Policy(),
            domainValidator: permissiveDomain)
        XCTAssertNotNil(mailbox)
        XCTAssertEqual(mailbox?.localPart, .dotAtom("alice"))
    }

    func testMailboxReturnsNilOnUTS39Failure() {
        // Bidi-lookalike with Cyrillic а in local part.
        let mailbox = EmailSyntaxValidator.mailbox(
            from: "p\u{0430}ypal@example.com",
            uts39: UTS39.Policy(),
            domainValidator: permissiveDomain)
        XCTAssertNil(mailbox)
    }

    // MARK: - Restriction level threading

    func testSingleScriptRejectsJapaneseMixViaConvenienceAPI() {
        let policy = UTS39.Policy(level: .singleScript)
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted(
            "user会社カナ@example.com",
            uts39: policy,
            domainValidator: permissiveDomain))
    }

    func testIdentifierStatusFlagThreadsThrough() {
        // Linear B (Restricted) in local part.
        let strict = UTS39.Policy(level: .moderatelyRestrictive, rejectRestrictedIdentifiers: true)
        let lenient = UTS39.Policy(level: .moderatelyRestrictive, rejectRestrictedIdentifiers: false)

        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted(
            "𐀀𐀁@example.com",
            uts39: strict,
            domainValidator: permissiveDomain))

        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "𐀀𐀁@example.com",
            uts39: lenient,
            domainValidator: permissiveDomain))
    }

    // MARK: - Default validator path (PSL integration)

    func testDefaultPSLPathAcceptsRealDomain() {
        // Without domainValidator override, PSL gating applies. Use a
        // well-known public domain that PSL accepts.
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "alice@example.com",
            uts39: UTS39.Policy()))
    }
}
