//
//  Base64PadderTests.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-27.
//  Copyrights (C) 2022, Dave Poirier.  Distributed under MIT license.

import XCTest
@testable import SwiftEmailValidator

class Base64PadderTests: XCTestCase {
    
    func testEmpty_staysEmpty() {
        XCTAssertEqual(Base64Padder.pad(""), "")
    }

    func testOneCharacter_appendsThreeEquals() {
        XCTAssertEqual(Base64Padder.pad("x"), "x===")
    }
    
    func testTwoCharacters_appendsTwo() {
        XCTAssertEqual(Base64Padder.pad("xx"), "xx==")
    }
    
    func testThreeCharacters_appendsOne() {
        XCTAssertEqual(Base64Padder.pad("xxx"), "xxx=")
    }
    
    func testFourCharacters_appendsNone() {
        XCTAssertEqual(Base64Padder.pad("xxxx"), "xxxx")
    }
    
    func testSampleBase64EncodedEmail_appendsNone() {
        XCTAssertEqual(Base64Padder.pad("7ZWcQHgu7ZWc6rWt"), "7ZWcQHgu7ZWc6rWt")
    }
    
    func testEncodeStripDecode_expectsSameValueOut() {
        for length in 0...64 {
            let expectedValue = String(repeating: "x", count: length)
            let base64 = expectedValue.data(using: .ascii)!.base64EncodedString()
            let truncatedBase64 = base64.replacingOccurrences(of: "=", with: "")
            let paddedBase64 = Base64Padder.pad(truncatedBase64)
            XCTAssertEqual(base64, paddedBase64)
        }
    }
}
