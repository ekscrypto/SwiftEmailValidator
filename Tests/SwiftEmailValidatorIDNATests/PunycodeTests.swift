//
//  PunycodeTests.swift
//  SwiftEmailValidatorIDNATests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Round-trip and golden-vector tests for the RFC 3492 codec.
//  Test vectors are taken from RFC 3492 §7.1 (Sample strings).
//

import XCTest
@testable import SwiftEmailValidatorIDNA

final class PunycodeTests: XCTestCase {

    /// RFC 3492 §7.1: known input → expected Punycode body pairs.
    private struct Vector {
        let unicode: String
        let punycode: String
        let label: String
    }

    private let vectors: [Vector] = [
        // (B) Chinese (simplified): 他们为什么不说中文
        Vector(unicode: "他们为什么不说中文",
               punycode: "ihqwcrb4cv8a8dqg056pqjye",
               label: "RFC 3492 §7.1 (B)"),
        // (D) Hebrew: למה הם פשוט לא מדברים עברית
        Vector(unicode: "למההםפשוטלאמדבריםעברית",
               punycode: "4dbcagdahymbxekheh6e0a7fei0b",
               label: "RFC 3492 §7.1 (D)"),
        // (G) Korean
        Vector(unicode: "세계의모든사람들이한국어를이해한다면얼마나좋을까",
               punycode: "989aomsvi5e83db1d2a355cv1e0vak1dwrv93d5xbh15a0dt30a5jpsd879ccm6fea98c",
               label: "RFC 3492 §7.1 (G)"),
        // (L) Japanese
        Vector(unicode: "ひとつ屋根の下2",
               punycode: "2-u9tlzr9756bt3uc0v",
               label: "RFC 3492 §7.1 (L)"),
    ]

    func testEncodeMatchesRFCVectors() {
        for v in vectors {
            XCTAssertEqual(Punycode.encode(v.unicode), v.punycode, v.label)
        }
    }

    func testDecodeMatchesRFCVectors() {
        for v in vectors {
            XCTAssertEqual(Punycode.decode(v.punycode), v.unicode, v.label)
        }
    }

    func testRoundTrip() {
        let inputs = [
            "münchen",
            "café",
            "日本語",
            "ελληνικά",
            "русский",
            "español",
        ]
        for input in inputs {
            guard let body = Punycode.encode(input) else {
                XCTFail("encode failed: \(input)"); continue
            }
            XCTAssertEqual(Punycode.decode(body), input, "round-trip: \(input)")
        }
    }

    func testEmptyAndASCIIOnly() {
        // Pure ASCII has no non-basic code points; encoder appends the
        // delimiter only when basic code points exist, but with no extension
        // the delimiter is conventionally omitted. Our encoder emits the
        // separator after copying basic code points, then nothing further.
        // RFC 3492 §3.1 allows but does not require the trailing delimiter
        // in this corner case; we pin our actual behavior.
        XCTAssertEqual(Punycode.encode("abc"), "abc-")
        XCTAssertEqual(Punycode.decode("abc-"), "abc")
    }

    func testDecodeRejectsInvalid() {
        XCTAssertNil(Punycode.decode("***"))           // non-digit basic char
        XCTAssertNil(Punycode.decode("a-!"))           // bad extension
    }
}
