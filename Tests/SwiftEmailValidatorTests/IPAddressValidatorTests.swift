//
//  IPAddressValidatorTests.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-21.
//  Copyrights (C) 2022, Dave Poirier.  Distributed under MIT license

import XCTest
@testable import SwiftEmailValidator

final class IPAddressValidatorTests: XCTestCase {

    let validIPv6Addresses: [String] = [
        "1:2:3:4:5:6:7:8",
        "::ffff:10.0.0.1",
        "::ffff:1.2.3.4",
        "::ffff:0.0.0.0",
        "1:2:3:4:5:6:77:88",
        "::ffff:255.255.255.255",
        "fe08::7:8",
        "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"
    ]
    
    let invalidIPv6Addresses: [String] = [
        "1:2:3:4:5:6:7:8:9",
        "1:2:3:4:5:6::7:8",
        ":1:2:3:4:5:6:7:8",
        "1:2:3:4:5:6:7:8:",
        "::1:2:3:4:5:6:7:8",
        "1:2:3:4:5:6:7:8::",
        "1:2:3:4:5:6:7:88888",
        "2001:db8:3:4:5::192.0.2.33",
        "fe08::7:8%",
        "fe08::7:8i",
        "fe08::7:8interface"
    ]
    
    let validIPv4Addresses: [String] = [
        "0.0.0.0",
        "9.9.9.9",
        "99.99.99.99",
        "199.199.199.199",
        "200.200.200.200",
        "255.255.255.255",
        "192.168.2.1",
        "10.0.3.57",
        "172.16.9.255"
    ]
    
    let invalidIPv4Addresses: [String] = [
        "0.0.0",
        "0.0.0.",
        ".0.0.0",
        ".0.0.0.0",
        "0.0.0.0.",
        "256.2.3.4",
        "1.256.3.4",
        "1.2.256.4",
        "1.2.3.256",
        "1000.2.3.4",
        "300.2.3.4"
    ]

    func testValidIPv6Addresses() {
        validIPv6Addresses.forEach { XCTAssertTrue(IPAddressSyntaxValidator.matchIPv6($0), "Expected \($0) to be a valid IPv6 address") }
    }
    
    func testInvalidIPv6Addresses() {
        invalidIPv6Addresses.forEach { XCTAssertFalse(IPAddressSyntaxValidator.matchIPv6($0), "Expected \($0) to be an invalid IPv6 address") }
        validIPv4Addresses.forEach { XCTAssertFalse(IPAddressSyntaxValidator.matchIPv6($0), "Expected \($0) to be a valid IPv4 but not a valid IPv6 address") }
    }
    
    func testValidIPv4Addresses() {
        validIPv4Addresses.forEach { XCTAssertTrue(IPAddressSyntaxValidator.matchIPv4($0), "Expected \($0) to be a valid IPv4 address") }
    }
    
    func testInvalidIPv4Addresses() {
        invalidIPv4Addresses.forEach { XCTAssertFalse(IPAddressSyntaxValidator.matchIPv4($0), "Expected \($0) to be an invalid IPv4 address") }
        validIPv6Addresses.forEach { XCTAssertFalse(IPAddressSyntaxValidator.matchIPv4($0), "Expected \($0) to be a valid IPv6 but not a valid IPv4 address") }
    }
    
    func testValidIPAddresses() {
        var allValidAddresses: [String] = []
        allValidAddresses.append(contentsOf: validIPv4Addresses)
        allValidAddresses.append(contentsOf: validIPv6Addresses)

        allValidAddresses.forEach { XCTAssertTrue(IPAddressSyntaxValidator.match($0), "Expected \($0) to be a valid IP (v4/v6) address") }
    }

    // MARK: - Phase 3: Extended IP Address Tests

    func testIPv6ZoneIdentifiers() {
        // Zone identifiers (fe80::1%eth0) are NOT valid per RFC 5321 §4.1.3.
        // Zone IDs are local-scope identifiers that have no meaning outside
        // the local machine and must not appear in email address literals.
        //
        // RFC 6874 specifies that when a zone ID appears in a URI, the '%'
        // separator is percent-encoded as `%25` (yielding `fe80::1%25eth0`).
        // Some callers may pass the URI form through to the email layer,
        // so cover both the bare and percent-encoded variants.
        let zoneAddresses = [
            "fe80::1%eth0",
            "fe80::1%en0",
            "fe80::1%1",
            "fe80::1%25eth0",   // RFC 6874 percent-encoded form
            "fe80::1%25en0",
            "fe80::1%251",
        ]
        for addr in zoneAddresses {
            XCTAssertFalse(IPAddressSyntaxValidator.matchIPv6(addr),
                           "Zone identifier '\(addr)' must be rejected per RFC 5321 §4.1.3 (RFC 6874 form also rejected)")
        }
    }

    func testIPv6LoopbackVariants() {
        // Various representations of loopback
        XCTAssertTrue(IPAddressSyntaxValidator.matchIPv6("::1"), "::1 loopback should be valid")
        XCTAssertTrue(IPAddressSyntaxValidator.matchIPv6("0:0:0:0:0:0:0:1"), "Full loopback should be valid")
    }

    func testIPv4MappedIPv6Extended() {
        // More IPv4-mapped IPv6 addresses
        let validMapped = [
            "::ffff:192.168.1.1",
            "::ffff:0.0.0.0",
            "::ffff:127.0.0.1"
        ]
        for addr in validMapped {
            XCTAssertTrue(IPAddressSyntaxValidator.matchIPv6(addr), "\(addr) IPv4-mapped should be valid")
        }
    }

    func testIPv4LeadingZeros() {
        // Leading zeros are ambiguous (decimal vs octal) and rejected per RFC compliance
        XCTAssertFalse(IPAddressSyntaxValidator.matchIPv4("192.168.001.001"), "Leading zeros in IPv4 octet should be rejected")
        XCTAssertFalse(IPAddressSyntaxValidator.matchIPv4("010.010.010.010"), "Leading zeros in IPv4 octet should be rejected")
        XCTAssertFalse(IPAddressSyntaxValidator.matchIPv4("001.002.003.004"), "Leading zeros in IPv4 octet should be rejected")
    }

    func testEmptyIPAddressStrings() {
        XCTAssertFalse(IPAddressSyntaxValidator.match(""), "Empty string should not be valid IP")
        XCTAssertFalse(IPAddressSyntaxValidator.matchIPv4(""), "Empty string should not be valid IPv4")
        XCTAssertFalse(IPAddressSyntaxValidator.matchIPv6(""), "Empty string should not be valid IPv6")
        XCTAssertFalse(IPAddressSyntaxValidator.match(" "), "Whitespace should not be valid IP")
        XCTAssertFalse(IPAddressSyntaxValidator.match("   "), "Multiple spaces should not be valid IP")
    }

    func testIPv6AllZerosCompressedDoubleColon() {
        // "::" is the compressed form of the all-zeros address 0:0:0:0:0:0:0:0 (RFC 4291 §2.2)
        // It is distinct from the loopback "::1" and must be accepted as a valid IPv6 address.
        XCTAssertTrue(IPAddressSyntaxValidator.matchIPv6("::"),
                      ":: (all-zeros compressed) must be a valid IPv6 address per RFC 4291")
        // Confirm related valid compressed forms also pass
        XCTAssertTrue(IPAddressSyntaxValidator.matchIPv6("::1"),    "::1 loopback must be valid")
        XCTAssertTrue(IPAddressSyntaxValidator.matchIPv6("1::"),    "1:: compressed form must be valid")
        XCTAssertTrue(IPAddressSyntaxValidator.matchIPv6("1::2"),   "1::2 compressed form must be valid")
    }

    func testIPv6Format2UncompressedWithEmbeddedIPv4() {
        // RFC 4291 §2.2 format 2: six uncompressed hex groups followed by a
        // trailing IPv4-in-dotted-decimal (e.g. `aaaa:…:aaaa:127.0.0.1`).
        // The upstream regex this validator is derived from only recognised
        // the compressed / IPv4-mapped forms; this exercises the added path.
        let valid: [String] = [
            "aaaa:aaaa:aaaa:aaaa:aaaa:aaaa:127.0.0.1",
            "0:0:0:0:0:0:1.2.3.4",              // canonical all-zeros + IPv4
            "0:0:0:0:0:ffff:192.168.1.1",       // IPv4-mapped, fully expanded
            "ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255", // length boundary (45 octets)
            "1:2:3:4:5:6:1.2.3.4",
        ]
        for addr in valid {
            XCTAssertTrue(IPAddressSyntaxValidator.matchIPv6(addr),
                          "\(addr) must be accepted (RFC 4291 §2.2 format 2)")
        }
    }

    func testIPv6Format2RejectsWrongGroupCount() {
        // Format 2 requires exactly six hex groups before the IPv4 suffix.
        // Five or seven hex groups must not match the new alternative.
        let invalid: [String] = [
            "1:2:3:4:5:1.2.3.4",            // only 5 hex groups
            "1:2:3:4:5:6:7:1.2.3.4",        // 7 hex groups — over by one
            "1:2:3:4:5:6:1.2.3",            // only 3 IPv4 octets
            "1:2:3:4:5:6:1.2.3.4.5",        // 5 IPv4 octets
            "1:2:3:4:5:6:256.1.2.3",        // IPv4 octet out of range
        ]
        for addr in invalid {
            XCTAssertFalse(IPAddressSyntaxValidator.matchIPv6(addr),
                           "\(addr) must be rejected (not a valid RFC 4291 §2.2 format 2)")
        }
    }

    func testIPv6TwoDoubleColonsRejected() {
        // RFC 4291 §2.2 rule 3: at most one "::" may appear in an address.
        // Two "::" sequences make the address ambiguous and must be rejected.
        let twoDoubleColons = [
            "1::2::3",
            "::1::2",
            "1::2::3::4",
            "fe80::1::1",
        ]
        for addr in twoDoubleColons {
            XCTAssertFalse(IPAddressSyntaxValidator.matchIPv6(addr),
                           "'\(addr)' contains two '::' groups and must be rejected per RFC 4291")
        }
    }

    // MARK: - Public-API length cap (DoS hardening)

    func testIPv4PublicWrapperRejectsOverlongInput() {
        // IPv4 addresses are at most 15 octets ("255.255.255.255"). The public
        // wrapper must reject anything longer up-front without invoking the
        // regex — guards against a caller passing a multi-megabyte string.
        let overlong = String(repeating: "1", count: 16)              // 16 octets
        let farOverlong = String(repeating: "1.2.3.4,", count: 1024)  // 8 KiB
        XCTAssertFalse(IPAddressSyntaxValidator.matchIPv4(overlong))
        XCTAssertFalse(IPAddressSyntaxValidator.matchIPv4(farOverlong))
    }

    func testIPv4PublicWrapperAcceptsBoundary() {
        XCTAssertTrue(IPAddressSyntaxValidator.matchIPv4("255.255.255.255"),   // exactly 15 octets
                      "15-octet IPv4 must be accepted by the public wrapper")
    }

    func testIPv6PublicWrapperRejectsOverlongInput() {
        // IPv6 max = 45 octets (`ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255`).
        let overlong = String(repeating: "f", count: 46)
        let farOverlong = String(repeating: "::1,", count: 1024)
        XCTAssertFalse(IPAddressSyntaxValidator.matchIPv6(overlong))
        XCTAssertFalse(IPAddressSyntaxValidator.matchIPv6(farOverlong))
    }

    func testIPv6PublicWrapperAcceptsLongestSupportedForm() {
        // Longest legal IPv6 literal per RFC 4291 §2.2 is 45 octets in
        // format 2 (six hex groups + four IPv4 octets, e.g. the boundary
        // string below). The public wrapper must accept the full length.
        XCTAssertTrue(IPAddressSyntaxValidator.matchIPv6("ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255"))
        // The 8-group hex-only form (39 octets) also accepted — second-longest.
        XCTAssertTrue(IPAddressSyntaxValidator.matchIPv6("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"))
    }

    func testMatchPublicWrapperRejectsOverlongInput() {
        let overlong = String(repeating: "1", count: 46)
        XCTAssertFalse(IPAddressSyntaxValidator.match(overlong))
    }

    // MARK: - RFC 4291 §2.2 case-insensitivity for IPv4-mapped form

    func testIPv4MappedAcceptsUppercaseFFFF() {
        // RFC 4291 §2.2: hex digits in IPv6 may be written in either upper or lower case.
        // The IPv4-mapped prefix `::ffff:` must therefore also be accepted as `::FFFF:`,
        // along with mixed-case variants.
        let valid: [String] = [
            "::FFFF:1.2.3.4",
            "::FFFF:192.168.1.1",
            "::FfFf:127.0.0.1",
            "::FFFF:0:1.2.3.4",     // optional `:0{1,4}` group, uppercase
        ]
        for addr in valid {
            XCTAssertTrue(IPAddressSyntaxValidator.matchIPv6(addr),
                          "\(addr) must be accepted: RFC 4291 §2.2 allows uppercase hex digits")
        }
    }

    // MARK: - RFC 3986 §3.2.2 leading-zero rejection in embedded IPv4

    func testIPv6EmbeddedIPv4RejectsLeadingZeros() {
        // The standalone `_matchIPv4` rejects octets like `001` / `09` (octal-ambiguity
        // per RFC 3986 §3.2.2). The IPv6-with-embedded-IPv4 path must agree — otherwise
        // the same dotted-quad gets two different verdicts depending on the host shape.
        let invalid: [String] = [
            "::ffff:192.168.001.001",
            "::ffff:192.168.1.01",
            "::01.02.03.04",
            "0:0:0:0:0:ffff:001.002.003.004",       // format 2 + embedded leading zeros
            "1:2:3:4:5:6:192.168.001.001",          // format 2 path
            "::1:2:3:4:192.168.001.001",            // ([0-9a-fA-F]:){1,4}: + embedded IPv4
        ]
        for addr in invalid {
            XCTAssertFalse(IPAddressSyntaxValidator.matchIPv6(addr),
                           "\(addr) must be rejected: leading zeros in embedded IPv4 octet (RFC 3986 §3.2.2)")
        }
    }
}
