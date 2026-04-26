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

    func testAcceptsCaseInsensitiveForUnicodeULabel() {
        // RFC 5891 §5.4 / UTS #46 §4: U-labels compare case-insensitively
        // under Unicode default case folding. The IANA TLD list bundles the
        // lowercase form (`бел`); the validator must accept the uppercase
        // form (`БЕЛ`) by relying on Swift's `String.lowercased()` (which
        // performs locale-independent Unicode default case folding).
        // This pins that the case-insensitivity guarantee is not silently
        // ASCII-only — a regression that switched to `.lowercased()` on a
        // CharacterSet-restricted slice would still pass `IANA.ORG` but
        // fail this Cyrillic case.
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("example.БЕЛ"))
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("example.БеЛ"))
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

    // Defensive redundancy: once `.arpa` is in `specialUseTLDs`, `home.arpa` is
    // already rejected by `testRejectsArpaInfrastructureSubdomains` above. This
    // test pins the `home.arpa` rule (RFC 8375) independently so that if a
    // future refactor narrows the `.arpa` blocklist (e.g. to delivery-only
    // labels), `home.arpa` still fails. See CLAUDE.md session 9 notes.
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

    // MARK: - Public-API input normalization
    //
    // `isPubliclyDeliverable(_:)` is a public entry point that may be called
    // directly with user-supplied or copy-pasted hostnames. It must trim
    // surrounding whitespace and fold IDNA-equivalent dot variants before
    // dispatching to the raw worker. `EmailSyntaxValidator` skips this work
    // by calling `_isPubliclyDeliverable(_:)` because its label-character
    // validation already rejects whitespace and Unicode dots upstream.

    func testTrimsSurroundingWhitespace() {
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable(" iana.org"))
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("iana.org "))
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("\tiana.org\n"))
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("  iana.org.  "))
    }

    func testFoldsUnicodeFullStopVariants() {
        // U+3002 IDEOGRAPHIC FULL STOP (commonly entered on CJK keyboards)
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("iana\u{3002}org"))
        // U+FF0E FULLWIDTH FULL STOP
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("iana\u{FF0E}org"))
        // U+FF61 HALFWIDTH IDEOGRAPHIC FULL STOP
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("iana\u{FF61}org"))
    }

    func testNormalizationStillEnforcesSpecialUseRules() {
        // Whitespace + Unicode dots cannot be used to smuggle a reserved
        // name past the special-use blocklist.
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable(" example.com"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("example\u{FF0E}com"))
        XCTAssertFalse(TLDDomainValidator.isPubliclyDeliverable("foo\u{3002}arpa"))
    }

    func testRawWorkerDoesNotNormalize() {
        // Defensive: pick cases where the lack of normalization actually
        // changes the answer, to prove the raw worker assumes pre-cleaned
        // input. Trailing whitespace lands in the TLD label and fails the
        // IANATLDs lookup; a Unicode full stop does not split labels and
        // collapses the host to a single label.
        XCTAssertFalse(TLDDomainValidator._isPubliclyDeliverable("iana.org "),
                       "Trailing whitespace contaminates the TLD label and should fail without normalization")
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("iana.org "),
                      "Public wrapper should trim and accept")
        XCTAssertFalse(TLDDomainValidator._isPubliclyDeliverable("iana\u{3002}org"),
                       "Unicode full stop does not split labels in the raw worker")
        XCTAssertTrue(TLDDomainValidator.isPubliclyDeliverable("iana\u{3002}org"),
                      "Public wrapper should fold U+3002 to '.' and accept")
    }
}
