//
//  IDNAIntegrationTests.swift
//  SwiftEmailValidatorIDNATests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Exercise the EmailSyntaxValidator convenience overloads that wire UTS #46
//  IDNA processing into the host validation stage.
//

import XCTest
import SwiftEmailValidator
@testable import SwiftEmailValidatorIDNA

final class IDNAIntegrationTests: XCTestCase {

    /// Permissive base: any non-empty domain. Strips IDNA processing from
    /// the TLDDomainValidator gate so we test IDNA semantics in isolation.
    private let allowAny: (String) -> Bool = { !$0.isEmpty }

    func testCorrectlyFormattedAcceptsUnicodeHost() {
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "user@münchen.de",
            idna: IDNA.Options(),
            domainValidator: allowAny))
    }

    func testCorrectlyFormattedAcceptsACEHost() {
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "user@xn--mnchen-3ya.de",
            idna: IDNA.Options(),
            domainValidator: allowAny))
    }

    func testCorrectlyFormattedFoldsFullwidthHost() {
        // Fullwidth ASCII domain still resolves through IDNA → "example.com".
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "user@ｅｘａｍｐｌｅ.com",
            idna: IDNA.Options(),
            domainValidator: allowAny))
    }

    func testCorrectlyFormattedRejectsDisallowedHostScalar() {
        // U+202E in the host is `disallowed`; IDNA must fail.
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted(
            "user@bad\u{202E}name.com",
            idna: IDNA.Options(),
            domainValidator: allowAny))
    }

    func testMailboxParsesUnicodeHost() {
        let mb = EmailSyntaxValidator.mailbox(
            from: "user@münchen.de",
            idna: IDNA.Options(),
            domainValidator: allowAny)
        XCTAssertNotNil(mb)
    }

    func testIDNADomainValidatorChainedToTLDValidator() {
        // Using the default `domainValidator` (TLDDomainValidator) plus
        // IDNA: a Unicode TLD-bearing input must round-trip to a valid
        // ACE TLD that the IANA list recognizes.
        //
        // "ευρώπη.eu" → ACE "xn--qxaeg9bxa5h.eu". The .eu TLD is in the
        // IANA list, so the chain accepts it.
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "user@ευρώπη.eu",
            idna: IDNA.Options()))
    }

    func testIDNADomainValidatorRejectsInvalidTLDAfterMapping() {
        // After IDNA processing, the TLD ".invalidtld" doesn't exist in
        // the IANA list. Even though IDNA would accept the structure,
        // the chained TLDDomainValidator rejects.
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted(
            "user@müller.invalidtld",
            idna: IDNA.Options()))
    }

    func testTransitionalChangesDeviationOutcome() {
        // "faß.de" — nontransitional keeps the ß; transitional folds to ss.
        // Both produce DNS-resolvable hosts, but the ASCII bytes differ.
        // We assert that the email-level validator accepts both modes.
        let nontrans = IDNA.Options(transitional: false)
        let trans = IDNA.Options(transitional: true)
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "user@faß.de", idna: nontrans, domainValidator: allowAny))
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "user@faß.de", idna: trans, domainValidator: allowAny))
    }
}
