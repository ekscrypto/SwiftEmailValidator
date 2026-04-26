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

    /// Accept any domain whose rightmost label is `com`. Replaces the
    /// legacy PSL-based test helper after the dependency was removed in
    /// 1.6.0 — preserves test isolation from the IANA list / special-use
    /// blocklist.
    private let comOnly: (String) -> Bool = { domain in
        let labels = domain.lowercased().split(separator: ".", omittingEmptySubsequences: false)
        return labels.count >= 2 && labels.allSatisfy { !$0.isEmpty } && labels.last == "com"
    }

    func testDefaultHookPreservesBehavior() {
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "user@site.com",
            domainValidator: comOnly))

        XCTAssertNotNil(EmailSyntaxValidator.mailbox(
            from: "first.last@site.com",
            domainValidator: comOnly))
    }

    func testHookRejectionSurfacesAsNil() {
        let rejectAll: (String) -> Bool = { _ in false }

        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted(
            "user@site.com",
            domainValidator: comOnly,
            localPartValidator: rejectAll))

        XCTAssertNil(EmailSyntaxValidator.mailbox(
            from: "first.last@site.com",
            domainValidator: comOnly,
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
            domainValidator: comOnly,
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
            domainValidator: comOnly,
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
            domainValidator: comOnly,
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
            domainValidator: comOnly,
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
        // `.asciiWithUnicodeExtension`. The hook is invoked on the
        // (successful) recursive pass exactly once.
        _ = EmailSyntaxValidator.mailbox(
            from: "héllo@site.com",
            options: [.autoEncodeToRfc2047],
            compatibility: .asciiWithUnicodeExtension,
            domainValidator: comOnly,
            localPartValidator: count)

        XCTAssertLessThanOrEqual(invocations, 1)
    }
}
