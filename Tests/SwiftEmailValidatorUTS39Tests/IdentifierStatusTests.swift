//
//  IdentifierStatusTests.swift
//  SwiftEmailValidatorUTS39Tests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//

import XCTest
@testable import SwiftEmailValidatorUTS39

final class IdentifierStatusTests: XCTestCase {

    func testCommonAsciiAllowed() {
        for cp: UInt32 in [0x30, 0x39, 0x41, 0x5A, 0x61, 0x7A, 0x2D, 0x2E] {
            let scalar = Unicode.Scalar(cp)!
            XCTAssertTrue(
                IdentifierStatusData.isAllowed(scalar),
                "U+\(String(cp, radix: 16, uppercase: true)) should be Allowed"
            )
        }
    }

    func testRestrictedHistoricScriptsRejected() {
        // UTS #39 Restricted: historic/obscure scripts that should not appear
        // in user identifiers.
        let restricted: [(name: String, scalar: UInt32)] = [
            ("Linear B",       0x10000),
            ("Runic",          0x16A0),
            ("Deseret",        0x10400),
            ("Old Italic",     0x10300),
            ("Phoenician",     0x10900),
            ("Cuneiform",      0x12000),
        ]
        for (name, cp) in restricted {
            guard let scalar = Unicode.Scalar(cp) else {
                XCTFail("scalar U+\(String(cp, radix: 16)) invalid")
                continue
            }
            XCTAssertFalse(
                IdentifierStatusData.isAllowed(scalar),
                "\(name) U+\(String(cp, radix: 16, uppercase: true)) should be Restricted"
            )
        }
    }

    func testEvaluateRejectsRestrictedWhenPolicyDemands() {
        let policy = UTS39.Policy(
            level: .moderatelyRestrictive,
            rejectRestrictedIdentifiers: true)

        // "𐀀" (U+10000 LINEAR B SYLLABLE B008 A) is Restricted.
        XCTAssertFalse(UTS39.evaluate("𐀀lias", policy: policy))
    }

    func testEvaluateAcceptsRestrictedWhenPolicyIsLenient() {
        let policy = UTS39.Policy(
            level: .moderatelyRestrictive,
            rejectRestrictedIdentifiers: false)

        // Still subject to mixed-script analysis; Linear B alone is a single
        // script so Single/Highly/Moderately Restrictive all pass.
        XCTAssertTrue(UTS39.evaluate("𐀀𐀁𐀂", policy: policy))
    }

    func testAllowedScriptsArePermittedAcrossBroadRange() {
        // Spot-check that common non-ASCII scripts in wide use are Allowed.
        let allowedSamples: [(name: String, scalar: UInt32)] = [
            ("Cyrillic а",    0x0430),
            ("Greek alpha",   0x03B1),
            ("Han 中",         0x4E2D),
            ("Hiragana あ",    0x3042),
            ("Hangul 가",      0xAC00),
            ("Arabic ش",       0x0634),
            ("Hebrew א",       0x05D0),
            ("Devanagari अ",  0x0905),
        ]
        for (name, cp) in allowedSamples {
            XCTAssertTrue(
                IdentifierStatusData.isAllowed(Unicode.Scalar(cp)!),
                "\(name) U+\(String(cp, radix: 16, uppercase: true)) should be Allowed"
            )
        }
    }
}
