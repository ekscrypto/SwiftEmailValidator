//
//  LocalPartValidatorHookTests.swift
//  SwiftEmailValidator
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Covers the `localPartValidator` extension-point closure on
//  `EmailSyntaxValidator.correctlyFormatted` and `mailbox(from:)`.
//

import XCTest
@testable import SwiftEmailValidator

final class LocalPartValidatorHookTests: XCTestCase {

    func testDefaultHookPreservesBehavior() {
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "user@site.com",
            domainValidator: comOnlyDomainValidator))

        XCTAssertNotNil(EmailSyntaxValidator.mailbox(
            from: "first.last@site.com",
            domainValidator: comOnlyDomainValidator))
    }

    func testHookRejectionSurfacesAsNil() {
        let rejectAll: (String) -> Bool = { _ in false }

        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted(
            "user@site.com",
            domainValidator: comOnlyDomainValidator,
            localPartValidator: rejectAll))

        XCTAssertNil(EmailSyntaxValidator.mailbox(
            from: "first.last@site.com",
            domainValidator: comOnlyDomainValidator,
            localPartValidator: rejectAll))
    }

    func testHookSeesDotAtomSemanticValue() {
        var captured: String?
        let capture: (String) -> Bool = { value in
            captured = value
            return true
        }

        _ = EmailSyntaxValidator.mailbox(
            from: "first.last@site.com",
            domainValidator: comOnlyDomainValidator,
            localPartValidator: capture)

        XCTAssertEqual(captured, "first.last")
    }

    func testHookSeesCleanedQuotedStringValue() {
        var captured: String?
        let capture: (String) -> Bool = { value in
            captured = value
            return true
        }

        // `"hello world"@site.com`: cleaned semantic form drops the surrounding
        // double-quotes. The hook must see the semantic value, not the raw form.
        _ = EmailSyntaxValidator.mailbox(
            from: "\"hello world\"@site.com",
            domainValidator: comOnlyDomainValidator,
            localPartValidator: capture)

        XCTAssertEqual(captured, "hello world")
    }

    func testHookSeesUnescapedQuotedStringValue() {
        var captured: String?
        let capture: (String) -> Bool = { value in
            captured = value
            return true
        }

        // `"a\"b"@site.com` — the escape `\"` decodes to a literal `"`.
        _ = EmailSyntaxValidator.mailbox(
            from: "\"a\\\"b\"@site.com",
            domainValidator: comOnlyDomainValidator,
            localPartValidator: capture)

        XCTAssertEqual(captured, "a\"b")
    }

    func testHookNotInvokedWhenRfcParsingFails() {
        var invocations = 0
        let count: (String) -> Bool = { _ in
            invocations += 1
            return true
        }

        // Missing local part — RFC parsing fails before the hook runs.
        XCTAssertNil(EmailSyntaxValidator.mailbox(
            from: "@site.com",
            domainValidator: comOnlyDomainValidator,
            localPartValidator: count))

        XCTAssertEqual(invocations, 0)
    }

    func testHookInvokedOnceOnAutoEncodeRetry() {
        var invocations = 0
        let count: (String) -> Bool = { _ in
            invocations += 1
            return true
        }

        // Unicode input that would auto-encode to RFC2047 under
        // `.asciiWithUnicodeExtension`. First pass: RFC2047.decode fails,
        // ASCII extraction rejects the non-ASCII scalar, then `candidateForRfc2047`
        // re-encodes and recurses. Second pass: RFC2047.decode succeeds, the
        // decoded form parses as a Unicode dot-atom, and the hook runs once.
        let result = EmailSyntaxValidator.mailbox(
            from: "héllo@site.com",
            options: [.autoEncodeToRfc2047],
            compatibility: .asciiWithUnicodeExtension,
            domainValidator: comOnlyDomainValidator,
            localPartValidator: count)

        XCTAssertNotNil(result, "Auto-encode retry path must succeed for Unicode input")
        XCTAssertEqual(invocations, 1, "Hook must be invoked exactly once on the successful retry pass")
    }
}
