//
//  InvariantTests.swift
//  SwiftEmailValidator
//
//  Property/invariant tests that sweep across scalar ranges deterministically
//  (no random seed — same inputs every run, reproducible CI). These complement
//  the targeted regression tests in EmailSyntaxValidatorTests by surfacing any
//  internal contract violations that wouldn't show up in hand-written cases.
//

import XCTest
@testable import SwiftEmailValidator

final class InvariantTests: XCTestCase {

    private let permissive: (String) -> Bool = { _ in true }

    /// `correctlyFormatted` must agree with `mailbox != nil` for every input.
    /// They share an implementation today, but the invariant is part of the
    /// public contract and a regression here would silently desync the two
    /// entry points users rely on.
    func testCorrectlyFormattedAgreesWithMailboxAcrossScalarRanges() {
        // Sweep ranges where bugs have historically clustered (BMP edges,
        // noncharacters, supplementary planes, the SSP/Tags region).
        let ranges: [ClosedRange<UInt32>] = [
            0x20...0x7E,        // ASCII printable
            0x80...0xFF,        // Latin-1 supplement (incl. C1 controls 0x80-0x9F)
            0x2000...0x2070,    // General punctuation (incl. blocked spaces & format chars)
            0xFDD0...0xFDEF,    // BMP §23.7 noncharacters
            0xFFFE...0xFFFF,    // BMP noncharacters
            0x1FFFE...0x1FFFF,  // SMP noncharacters
            0x2FFFE...0x2FFFF,  // SIP noncharacters
            0x3FFFE...0x3FFFF,  // TIP noncharacters
            0xE0000...0xE007F,  // Tags block
            0x10FFFC...0x10FFFF,// Last PUA scalars
        ]
        for range in ranges {
            for value in range {
                guard let scalar = Unicode.Scalar(value) else { continue } // skip surrogates
                let candidate = "user\(scalar)@site.com"
                let asMailbox = EmailSyntaxValidator.mailbox(
                    from: candidate, compatibility: .unicode, domainValidator: permissive)
                let asBool = EmailSyntaxValidator.correctlyFormatted(
                    candidate, compatibility: .unicode, domainValidator: permissive)
                XCTAssertEqual(asBool, asMailbox != nil,
                    "correctlyFormatted/mailbox disagree for U+\(String(value, radix: 16, uppercase: true))")
            }
        }
    }

    /// Both local-part extractors must reject the same supplementary-plane
    /// scalars. They each route through `isRejectedSupplementaryScalar`; if
    /// either path stops calling the helper, this test fires.
    func testDotAtomAndQuotedStringRejectSameSupplementaryScalars() {
        let supplementaryProbes: [UInt32] = [
            0x1FFFE, 0x1FFFF,           // Plane 1 noncharacters
            0x2FFFE, 0x2FFFF,           // Plane 2 noncharacters
            0x3FFFE, 0x3FFFF,           // Plane 3 noncharacters
            0x40000, 0x80000, 0xDFFFF,  // Planes 4-13 spot checks
            0xE0000, 0xE0041, 0xE007F,  // SSP / Tags
            0xF0000, 0x100000, 0x10FFFF // PUA-A/B
        ]
        for value in supplementaryProbes {
            guard let scalar = Unicode.Scalar(value) else { continue }
            let dotAtomCandidate = "user\(scalar)@site.com"
            let quotedCandidate = "\"user\(scalar)\"@site.com"
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: dotAtomCandidate, compatibility: .unicode, domainValidator: permissive),
                "Dot-atom must reject U+\(String(value, radix: 16, uppercase: true))")
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: quotedCandidate, compatibility: .unicode, domainValidator: permissive),
                "Quoted-string must reject U+\(String(value, radix: 16, uppercase: true))")
        }
    }

    /// `.ascii` and `.unicode` modes must agree exactly across the ASCII printable
    /// range. The Unicode mode is a proper superset of ASCII *only* via non-ASCII
    /// scalars; inside U+0020–U+007E the two modes share `atextCharacterSet` and
    /// `qtextSMTPCharacterSet`, so the accept/reject verdict must match for every
    /// scalar. Asymmetric tests would let a future change (e.g. tightening Unicode
    /// mode but leaving ASCII alone, or vice versa) drift undetected for ASCII
    /// inputs — the inputs most callers actually pass.
    func testAsciiAndUnicodeAgreeOnPrintableASCII() {
        for value in UInt32(0x20)...UInt32(0x7E) {
            guard let scalar = Unicode.Scalar(value) else { continue }
            let candidate = "u\(scalar)r@site.com"
            let asciiOK = EmailSyntaxValidator.correctlyFormatted(
                candidate, compatibility: .ascii, domainValidator: permissive)
            let unicodeOK = EmailSyntaxValidator.correctlyFormatted(
                candidate, compatibility: .unicode, domainValidator: permissive)
            XCTAssertEqual(asciiOK, unicodeOK,
                "ASCII and Unicode modes must agree on '\(candidate)' (scalar U+\(String(value, radix: 16, uppercase: true))) — ascii=\(asciiOK), unicode=\(unicodeOK)")
        }
    }

    /// `IANATLDs.all` is queried via `s.lowercased()` lookups. The generator
    /// (`Tools/generate_tlds.py`) lowercases every entry — both ACE labels via
    /// `.lower()` and U-labels via `idna.decode(label).lower()`. Lock that
    /// invariant in the type system: if a regenerator ever shipped a mixed-case
    /// entry, every email validation call routed through that TLD would silently
    /// fail despite the TLD being registered.
    func testGeneratedTLDsAreAllLowercase() {
        XCTAssertTrue(
            IANATLDs.all.allSatisfy { $0 == $0.lowercased() },
            "Every entry in IANATLDs.all must be lowercase — _isPubliclyDeliverable lowercases input before lookup, so a mixed-case generated entry would be unreachable")
    }

    /// Validator must never crash or hang on arbitrary byte-sized inputs, AND
    /// the dual-API contract (`correctlyFormatted` returns true iff `mailbox`
    /// returns non-nil) must hold for every candidate. The triple-byte sweep
    /// would otherwise pass vacuously — the assertion inside the loop turns
    /// it into a real fuzz invariant. Both `.ascii` and `.unicode` modes are
    /// exercised so a regression in either path fires.
    func testValidatorNeverCrashesOnShortByteStrings() {
        let probeBytes: [UInt8] = [
            0x00, 0x09, 0x0A, 0x0D, 0x1F,           // controls
            0x20, 0x22, 0x27, 0x2E, 0x40, 0x5B, 0x5D, 0x5C, // punctuation that drives parser branches
            0x41, 0x61, 0x30,                        // letters/digits
            0x7E, 0x7F, 0x80, 0xFF                   // edge bytes
        ]
        for b1 in probeBytes {
            for b2 in probeBytes {
                for b3 in probeBytes {
                    let bytes: [UInt8] = [b1, b2, b3]
                    guard let candidate = String(bytes: bytes, encoding: .utf8) else { continue }
                    let mbU = EmailSyntaxValidator.mailbox(
                        from: candidate, compatibility: .unicode, domainValidator: permissive)
                    let cfU = EmailSyntaxValidator.correctlyFormatted(
                        candidate, compatibility: .unicode, domainValidator: permissive)
                    XCTAssertEqual(cfU, mbU != nil,
                        "Unicode mode disagree on bytes \(bytes.map { String(format: "%02x", $0) })")
                    let mbA = EmailSyntaxValidator.mailbox(
                        from: candidate, compatibility: .ascii, domainValidator: permissive)
                    let cfA = EmailSyntaxValidator.correctlyFormatted(
                        candidate, compatibility: .ascii, domainValidator: permissive)
                    XCTAssertEqual(cfA, mbA != nil,
                        "ASCII mode disagree on bytes \(bytes.map { String(format: "%02x", $0) })")
                }
            }
        }
    }
}
