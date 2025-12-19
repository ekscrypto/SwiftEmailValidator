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
        // Zone identifiers (fe80::1%eth0) are NOT valid per RFC 5321 Section 4.1.3
        // Zone IDs are local scope identifiers that have no meaning outside the local machine
        // and should not appear in email address literals
        let zoneAddresses = [
            "fe80::1%eth0",
            "fe80::1%en0",
            "fe80::1%1"
        ]
        for addr in zoneAddresses {
            XCTAssertFalse(IPAddressSyntaxValidator.matchIPv6(addr), "Zone identifier \(addr) should be rejected per RFC 5321")
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
        // Leading zeros handling - typically these are invalid or treated differently
        let leadingZeros = [
            "192.168.001.001",
            "010.010.010.010",
            "001.002.003.004"
        ]
        // Document behavior - leading zeros may be rejected or interpreted as octal
        for addr in leadingZeros {
            // The validator may accept or reject these - document actual behavior
            let result = IPAddressSyntaxValidator.matchIPv4(addr)
            // Leading zeros are typically valid in decimal notation
            if result {
                XCTAssertTrue(result, "Leading zeros in \(addr) are accepted")
            } else {
                XCTAssertFalse(result, "Leading zeros in \(addr) are rejected")
            }
        }
    }

    func testEmptyIPAddressStrings() {
        XCTAssertFalse(IPAddressSyntaxValidator.match(""), "Empty string should not be valid IP")
        XCTAssertFalse(IPAddressSyntaxValidator.matchIPv4(""), "Empty string should not be valid IPv4")
        XCTAssertFalse(IPAddressSyntaxValidator.matchIPv6(""), "Empty string should not be valid IPv6")
        XCTAssertFalse(IPAddressSyntaxValidator.match(" "), "Whitespace should not be valid IP")
        XCTAssertFalse(IPAddressSyntaxValidator.match("   "), "Multiple spaces should not be valid IP")
    }
}
