//
//  RFC2047CoderTests.swift
//  
//
//  Created by Dave Poirier on 2022-01-22.
//

import XCTest
@testable import SwiftEmailValidator

final class RFC2047CoderTests: XCTestCase {

    func testDecodingUTF8B() {
        let value = "ந்தி@யா.இந்தியா"
        let base64 = value.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let rfc2047Encoded = "=?utf-8?b?\(base64)?="
        XCTAssertEqual(RFC2047Coder.decode(rfc2047Encoded), value)
    }
    
    func testDecodingLatin1Q() {
        XCTAssertEqual(RFC2047Coder.decode("=?iso-8859-1?q?h=E9ro@cinema.ca?="), "héro@cinema.ca")
        XCTAssertEqual(RFC2047Coder.decode("=?iso-8859-1?q?Santa=20Claus?="), "Santa Claus")
        XCTAssertEqual(RFC2047Coder.decode("=?iso-8859-1?q?\"Santa=20Claus\"@x=20.com?="), #""Santa Claus"@x .com"#)
    }
    
    func testDecodingInvalidCharset() {
        XCTAssertNil(RFC2047Coder.decode("=?schtroomf?b?shackalaka?="),"When an unknown charset is provided decoding should fail")
    }
    
    func testDecodingInvalidEncoding() {
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?r?h=E9ro@cinema.ca?="),"Per RFC2047 valid values are B / Q, a value or R should therefore fail decoding")
    }
    
    func testDecodingLatin1QWithIncompleteString() {
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q?h=E9ro@cinema.ca?"), "Incorrectly terminated encoded text should not be decodable")
    }
    
    func testDecodingUTF8BWithInvalidBase64Characters() {
        let value = "ந்தி@யா.இந்தியா"
        let base64 = value.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let rfc2047Encoded = "=?utf-8?b?\(base64)!@#$%^&*()?="
        XCTAssertNil(RFC2047Coder.decode(rfc2047Encoded), "If invalid characters are present within the expected base64 encoded text, decoding should fail")
    }

    func testDecodingValueTooLarge() {
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q?1234567890123456789012345678901234567890123456789012345678901234567890@toolong.net?="))
    }
    
    func testCurrentlyUnsupportedUTF8Q() {
        XCTAssertNil(RFC2047Coder.decode("=?utf8?q?hello=64@site.com?="),"There doesn't seem to be any details in RFC2047 on how to handle this case, skipping for now")
    }
    
    func testDecodingLatin1QInvalidHexDigit() {
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q?h=G9ro@cinema.ca?="), "G is not a valid hex digit and should cause decoding to fail")
    }
    
    func testDecodingLatin1QControlCharacter() {
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q?h=09ro@cinema.ca?="), "Hex value 09 resolves to a control character that should not be used in an email")
    }
    
    func testDecodingLatin1QIncompleteHex() {
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q?hero@cinema.c=3?="), "Failure to find 2 hex digits after = should fail decoding")
    }
    
    func testDecodingUnencoded() {
        XCTAssertNil(RFC2047Coder.decode("notEncoded@site.com"), "If the =? ?= signatures are missing, decoding should fail")
    }
    
    func testDecodingUtf8Chinese() {
        XCTAssertEqual(RFC2047Coder.decode("=?utf-8?B?7ZWcQHgu7ZWc6rWt?="), "한@x.한국")
    }
    
    func testInvalidBase64String() {
        XCTAssertNil(RFC2047Coder.decode("=?utf-8?B?7?="), "Not enough base64 characters to decode a full byte")
        XCTAssertNil(RFC2047Coder.decode("=?utf-8?B?7x_?="), "Invalid base64 character _")
    }
    
    func testDecodingUtf8QEncoded() {
        XCTAssertNil(RFC2047Coder.decode("=?utf-8?Q?thisShouldNotWork@site.com?="), "Q encoding not currently supported for UTF-8 by this library, not sure it's even supported in any library..")
    }
    
    func testEncoding() {
        XCTAssertEqual(RFC2047Coder.encode("한@x.한국"), "=?utf-8?b?7ZWcQHgu7ZWc6rWt?=")
    }
}
