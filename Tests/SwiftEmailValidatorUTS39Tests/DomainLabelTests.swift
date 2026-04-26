//
//  DomainLabelTests.swift
//  SwiftEmailValidatorUTS39Tests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//

import XCTest
@testable import SwiftEmailValidatorUTS39

final class DomainLabelTests: XCTestCase {

    /// Permissive base that accepts any domain — isolates UTS #39 label
    /// analysis from the default IANA TLD / special-use registrability check.
    private let allowAnyBase: (String) -> Bool = { _ in true }

    func testPureLatinDomainAccepted() {
        let validator = UTS39.domainValidator(UTS39.Policy(), base: allowAnyBase)
        XCTAssertTrue(validator("example.com"))
    }

    func testMixedScriptLabelRejected() {
        // "paypаl" label — Cyrillic а mixed with Latin. Highly Restrictive
        // rejects.
        let validator = UTS39.domainValidator(UTS39.Policy(), base: allowAnyBase)
        let spoofDomain = "payp\u{0430}l.com"
        XCTAssertFalse(validator(spoofDomain))
    }

    func testPureCyrillicDomainAcceptedUnderHighlyRestrictive() {
        // A label in pure Cyrillic is single-script so passes Highly
        // Restrictive. The default validator would reject non-IANA TLDs,
        // but here we use the permissive base so we test the UTS #39
        // layer in isolation.
        let validator = UTS39.domainValidator(UTS39.Policy(), base: allowAnyBase)
        XCTAssertTrue(validator("пример.com"))
    }

    func testEachLabelCheckedIndependently() {
        // Healthy labels separately — one label mixed-script must still
        // sink the whole domain.
        let validator = UTS39.domainValidator(UTS39.Policy(), base: allowAnyBase)
        XCTAssertTrue(validator("example.co.uk"))
        // "exаmple.co.uk" with Cyrillic а — only the first label is bad,
        // the whole domain still fails.
        let spoofed = "ex\u{0430}mple.co.uk"
        XCTAssertFalse(validator(spoofed))
    }

    func testPunycodeAceLabelsPass() {
        // ACE labels are pure ASCII Latin + digits + hyphen — always
        // single-script.
        let validator = UTS39.domainValidator(UTS39.Policy(), base: allowAnyBase)
        XCTAssertTrue(validator("xn--nxasmq6b.com"))
    }

    func testDomainValidatorDelegatesToBase() {
        // Base rejection always wins, even when UTS #39 would pass.
        let rejectAll: (String) -> Bool = { _ in false }
        let validator = UTS39.domainValidator(UTS39.Policy(), base: rejectAll)
        XCTAssertFalse(validator("example.com"))
    }
}
