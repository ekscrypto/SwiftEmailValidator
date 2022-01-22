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
}
