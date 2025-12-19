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

    // MARK: - Phase 1: UTF-16/UTF-32 Tests

    func testDecodingUTF16B() {
        // "test" in UTF-16 with BOM
        let testString = "test"
        guard let utf16Data = testString.data(using: .utf16) else {
            XCTFail("Failed to encode test string as UTF-16")
            return
        }
        let base64 = utf16Data.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let rfc2047Encoded = "=?utf-16?b?\(base64)?="
        XCTAssertEqual(RFC2047Coder.decode(rfc2047Encoded), testString, "UTF-16 base64 encoded string should decode correctly")
    }

    func testDecodingUTF32B() {
        // "hi" in UTF-32 with BOM
        let testString = "hi"
        guard let utf32Data = testString.data(using: .utf32) else {
            XCTFail("Failed to encode test string as UTF-32")
            return
        }
        let base64 = utf32Data.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let rfc2047Encoded = "=?utf-32?b?\(base64)?="
        XCTAssertEqual(RFC2047Coder.decode(rfc2047Encoded), testString, "UTF-32 base64 encoded string should decode correctly")
    }

    func testDecodingUTF16InvalidData() {
        // UTF-16 with invalid surrogate pair (high surrogate without low)
        // 0xD800 is a high surrogate, needs a low surrogate (0xDC00-0xDFFF) to follow
        let invalidUtf16Data = Data([0xD8, 0x00, 0xD8, 0x00]) // Two high surrogates
        let invalidBase64 = invalidUtf16Data.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let rfc2047Encoded = "=?utf-16?b?\(invalidBase64)?="
        // Document actual behavior - may return nil or empty depending on implementation
        let result = RFC2047Coder.decode(rfc2047Encoded)
        // Swift's String(data:encoding:) may return nil or replacement character for invalid sequences
        XCTAssertTrue(result == nil || result == "" || result?.contains("\u{FFFD}") == true,
                      "Invalid UTF-16 surrogate sequence should fail or produce replacement characters")
    }

    func testDecodingUTF32InvalidData() {
        // UTF-32 with invalid code point (beyond Unicode range)
        // Code points > 0x10FFFF are invalid
        let invalidUtf32Data = Data([0x00, 0x20, 0x00, 0x00]) // 0x200000 - invalid
        let invalidBase64 = invalidUtf32Data.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let rfc2047Encoded = "=?utf-32?b?\(invalidBase64)?="
        // Document actual behavior
        let result = RFC2047Coder.decode(rfc2047Encoded)
        XCTAssertTrue(result == nil || result == "" || result?.contains("\u{FFFD}") == true,
                      "Invalid UTF-32 code point should fail or produce replacement characters")
    }

    // MARK: - Phase 1: Round-Trip Tests

    func testEncodeDecodeRoundTripSimpleASCII() {
        let original = "user@domain.com"
        guard let encoded = RFC2047Coder.encode(original),
              let decoded = RFC2047Coder.decode(encoded) else {
            XCTFail("Round-trip encoding/decoding failed for ASCII string")
            return
        }
        XCTAssertEqual(decoded, original, "ASCII string should survive encode/decode round-trip")
    }

    func testEncodeDecodeRoundTripUnicode() {
        let testCases = [
            "한@x.한국",
            "café@bistro.fr",
            "用户@例子.中国"
        ]
        for original in testCases {
            guard let encoded = RFC2047Coder.encode(original),
                  let decoded = RFC2047Coder.decode(encoded) else {
                XCTFail("Round-trip encoding/decoding failed for: \(original)")
                continue
            }
            XCTAssertEqual(decoded, original, "Unicode string '\(original)' should survive encode/decode round-trip")
        }
    }

    func testEncodeDecodeRoundTripSpecialCharacters() {
        let testCases = [
            "test.user+tag@example.com",
            "hello_world@test.org",
            "a!b#c$d%e@site.com"
        ]
        for original in testCases {
            guard let encoded = RFC2047Coder.encode(original),
                  let decoded = RFC2047Coder.decode(encoded) else {
                XCTFail("Round-trip encoding/decoding failed for: \(original)")
                continue
            }
            XCTAssertEqual(decoded, original, "Special character string '\(original)' should survive encode/decode round-trip")
        }
    }

    // MARK: - Phase 3: ISO-8859-2 Tests

    func testDecodingLatin2QPolishCharacters() {
        // Polish "ą" is 0xB1 in ISO-8859-2
        XCTAssertEqual(RFC2047Coder.decode("=?iso-8859-2?q?=B1@site.com?="), "ą@site.com", "Polish ą should decode correctly from ISO-8859-2")
    }

    func testDecodingLatin2QCzechCharacters() {
        // Czech "ě" is 0xEC in ISO-8859-2
        XCTAssertEqual(RFC2047Coder.decode("=?iso-8859-2?q?=EC@site.com?="), "ě@site.com", "Czech ě should decode correctly from ISO-8859-2")
    }

    func testDecodingLatin2InvalidControlCharacter() {
        // Control character 0x09 (TAB) should be rejected
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-2?q?=09@site.com?="), "Control characters should be rejected in ISO-8859-2")
    }

    // MARK: - Phase 4: Encoding Edge Cases

    func testEncodeEmptyString() {
        let result = RFC2047Coder.encode("")
        XCTAssertNotNil(result, "Empty string should be encodable")
        if let encoded = result {
            XCTAssertEqual(RFC2047Coder.decode(encoded), "", "Empty string should round-trip correctly")
        }
    }

    func testDecodeWithMixedCaseCharset() {
        // Test case-insensitive charset matching
        let value = "test"
        guard let utf8Data = value.data(using: .utf8) else {
            XCTFail("Failed to encode test string")
            return
        }
        let base64 = utf8Data.base64EncodedString().replacingOccurrences(of: "=", with: "")

        XCTAssertEqual(RFC2047Coder.decode("=?UTF-8?b?\(base64)?="), value, "Uppercase charset should be accepted")
        XCTAssertEqual(RFC2047Coder.decode("=?Utf-8?b?\(base64)?="), value, "Mixed case charset should be accepted")
    }

    func testDecodeWithMixedCaseEncoding() {
        let value = "test"
        guard let utf8Data = value.data(using: .utf8) else {
            XCTFail("Failed to encode test string")
            return
        }
        let base64 = utf8Data.base64EncodedString().replacingOccurrences(of: "=", with: "")

        XCTAssertEqual(RFC2047Coder.decode("=?utf-8?B?\(base64)?="), value, "Uppercase B encoding should be accepted")
        XCTAssertEqual(RFC2047Coder.decode("=?utf-8?b?\(base64)?="), value, "Lowercase b encoding should be accepted")
    }

    func testDecodeWithWhitespaceInEncodedWord() {
        // RFC2047 encoded words should not contain literal spaces in the encoded-text portion
        XCTAssertNil(RFC2047Coder.decode("=?utf-8?b?dGVz dA?="), "Spaces in encoded text should cause failure or be handled per RFC")
    }
}
