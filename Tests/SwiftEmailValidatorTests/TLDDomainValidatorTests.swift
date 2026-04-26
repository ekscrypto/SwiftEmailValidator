//
//  TLDDomainValidatorTests.swift
//  SwiftEmailValidator
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//

import XCTest
@testable import SwiftEmailValidator

final class TLDDomainValidatorTests: XCTestCase {

    // MARK: - Real IANA TLDs accepted

    func testAcceptsCommonTLDs() {
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("iana.org"))
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("apple.com"))
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("bbc.co.uk"))
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("kremlin.ru"))
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("nic.app"))
    }

    func testAcceptsCaseInsensitive() {
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("IANA.ORG"))
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("Apple.Com"))
    }

    func testAcceptsTrailingRootDot() {
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("iana.org."))
    }

    func testAcceptsAceTLD() {
        // .中国 == xn--fiqs8s
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("example.xn--fiqs8s"))
    }

    func testAcceptsUnicodeTLD() {
        // Same as above but in U-label form
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("example.中国"))
    }

    // MARK: - Fake / unknown TLDs rejected

    func testRejectsFakeTLD() {
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("anything.notarealtld"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo.zzzzzzz"))
    }

    func testRejectsBareTLD() {
        // "com" alone has no labels below it.
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("com"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("uk"))
    }

    func testRejectsSingleLabelHosts() {
        // RFC 5321 requires FQDN.
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("localhost"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("mailserver"))
    }

    func testRejectsEmptyAndMalformed() {
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable(""))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("."))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo..com"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable(".foo.com"))
    }

    // MARK: - RFC 6761 / 6762 / 7686 / 8375 / 9476 special-use names rejected

    func testRejectsSpecialUseTLDs() {
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo.arpa"),       "RFC 3172")
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo.test"),       "RFC 6761 §6.2")
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo.example"),    "RFC 6761 §6.5")
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo.invalid"),    "RFC 6761 §6.4")
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo.localhost"),  "RFC 6761 §6.3")
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo.local"),      "RFC 6762 mDNS")
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo.onion"),      "RFC 7686 Tor")
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo.alt"),        "RFC 9476")
    }

    func testRejectsArpaInfrastructureSubdomains() {
        // RFC 3172: arpa is infrastructure-only (no MTA delivery).
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo.in-addr.arpa"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("1.0.0.127.in-addr.arpa"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("x.ip6.arpa"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("iris.arpa"))
    }

    func testRejectsReservedExampleDomains() {
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("example.com"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("example.net"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("example.org"))
    }

    func testRejectsSubdomainsOfReservedExamples() {
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo.example.com"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("a.b.example.org"))
    }

    func testRejectsHomeArpa() {
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("home.arpa"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("router.home.arpa"))
    }

    // MARK: - Acts as default in EmailSyntaxValidator

    func testWiringAsDefaultValidator() {
        // Default closure path — no override.
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted("hostmaster@iana.org"))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("hostmaster@example.com"),
                       "Default validator should reject RFC 6761 reserved name")
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("user@host.notarealtld"),
                       "Default validator should reject unknown TLD")
    }

    func testOverridableForIntranet() {
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(
            "user@mail.corp",
            domainValidator: { _ in true }))
    }
}
