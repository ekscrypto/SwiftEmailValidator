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

    func testDecodingQEncodingUnderscoreAsSpace() {
        // RFC 2047 §4.2: '_' may be used to represent a space in Q encoding
        XCTAssertEqual(RFC2047Coder.decode("=?iso-8859-1?q?Santa_Claus?="), "Santa Claus",
                       "Underscore in Q encoding should decode as space per RFC 2047 §4.2")
        XCTAssertEqual(RFC2047Coder.decode("=?iso-8859-1?q?hello_world?="), "hello world",
                       "Underscore in Q encoding should decode as space")
        // Underscore and =20 should produce identical results
        XCTAssertEqual(RFC2047Coder.decode("=?iso-8859-1?q?A_B?="),
                       RFC2047Coder.decode("=?iso-8859-1?q?A=20B?="),
                       "Underscore and =20 must produce identical output")
        // Underscore in quoted-string email local part
        XCTAssertEqual(RFC2047Coder.decode("=?iso-8859-1?q?\"Santa_Claus\"@site.com?="), "\"Santa Claus\"@site.com",
                       "Underscore in Q-encoded quoted-string local part should become a space")
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

    func testDecodingQEncodingRejectsDELChar() {
        // DEL (U+007F / 0x7F) sits outside the printable ASCII range (0x20-0x7E) and must
        // be rejected from Q-encoded content. Previously value >= 0x20 passed 0x7F through.
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q?=7F?="),
                     "DEL character (0x7F) must be rejected from Q-encoded content")
        // Confirm the byte just below (0x7E '~') is still accepted
        XCTAssertEqual(RFC2047Coder.decode("=?iso-8859-1?q?=7E?="), "~",
                       "0x7E ('~') is the last valid printable ASCII and must still decode")
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

    func testDecodingLatin1QAcceptsYUmlaut() {
        // 0xFF in ISO-8859-1 is ÿ (U+00FF, LATIN SMALL LETTER Y WITH DIAERESIS), a valid character
        XCTAssertEqual(RFC2047Coder.decode("=?iso-8859-1?q?=FF?="), "ÿ",
                       "0xFF (ÿ) should be accepted as a valid ISO-8859-1 character")
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
        // UTF-16 with invalid surrogate pair (high surrogate without low).
        // 0xD800 is a high surrogate; UTF-16 requires it be followed by a
        // low surrogate (0xDC00-0xDFFF). Two high surrogates back-to-back
        // are malformed regardless of platform endianness.
        let invalidUtf16Data = Data([0xD8, 0x00, 0xD8, 0x00])
        let invalidBase64 = invalidUtf16Data.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let rfc2047Encoded = "=?utf-16?b?\(invalidBase64)?="
        let result = RFC2047Coder.decode(rfc2047Encoded)
        // The previous assertion accepted three disjoint outcomes (nil, "",
        // or contains U+FFFD), which would have passed even if a future
        // Foundation release silently accepted the bytes as a valid two-
        // scalar string. Pin the actual platform behavior. CI runs on
        // macOS where Foundation rejects this payload outright (returns
        // nil); other platforms keep the lenient assertion until probed.
        #if canImport(Darwin)
        XCTAssertNil(result,
                     "Foundation on Darwin must reject this invalid UTF-16 payload outright (returns nil from String(data:encoding:.utf16))")
        #else
        XCTAssertTrue(result == nil || result == "" || result?.contains("\u{FFFD}") == true,
                      "Non-Darwin Foundation: invalid UTF-16 surrogate sequence should fail or produce replacement characters")
        #endif
    }

    func testDecodingUTF32InvalidData() {
        // UTF-32 with an out-of-Unicode-range code point. 0x00200000 is
        // above the Unicode max (0x10FFFF) and is invalid in UTF-32 BE;
        // 0x00002000 is U+2000 (EN QUAD, valid) in UTF-32 LE — so the
        // platform-endian fallback decision matters here.
        let invalidUtf32Data = Data([0x00, 0x20, 0x00, 0x00])
        let invalidBase64 = invalidUtf32Data.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let rfc2047Encoded = "=?utf-32?b?\(invalidBase64)?="
        let result = RFC2047Coder.decode(rfc2047Encoded)
        // Same rationale as the UTF-16 test above. Pin the Darwin
        // behavior (nil); leave the lenient three-way OR for non-Darwin.
        #if canImport(Darwin)
        XCTAssertNil(result,
                     "Foundation on Darwin must reject this UTF-32 payload outright (returns nil from String(data:encoding:.utf32))")
        #else
        XCTAssertTrue(result == nil || result == "" || result?.contains("\u{FFFD}") == true,
                      "Non-Darwin Foundation: invalid UTF-32 code point should fail or produce replacement characters")
        #endif
    }

    // MARK: - Phase 1: Round-Trip Tests

    func testEncodeDecodeRoundTripSimpleASCII() {
        let original = "user@domain.com"
        guard let encoded = RFC2047Coder.encode(original),
              let decoded = RFC2047Coder.decode(encoded) else {
            XCTFail("Round-trip encoding/decoding failed for ASCII string")
            return
        }
        // Pin the canonical wire form. Without this, a future encoder change that
        // produced any reversible blob (e.g. a different charset/encoding triplet,
        // hex, or an obfuscation scheme) would still satisfy the equality below.
        // 15-byte ASCII payload → 20 base64 chars, no `=` padding (15 % 3 == 0).
        XCTAssertEqual(encoded, "=?utf-8?b?dXNlckBkb21haW4uY29t?=",
                       "Encoded intermediate must match the canonical RFC 2047 wire form")
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

    func testEncodeEmptyStringDoesNotRoundTrip() {
        // The encoder still produces a syntactically-shaped wrapper for "" —
        // namely "=?utf-8?b??=" — but RFC 2047 §2 forbids empty encoded-text
        // (encoded-text = 1*<...>), so the decoder must reject it. This is
        // the documented one-way edge case: encoding empty inputs is legal
        // call-site behavior, but the resulting word is not a valid RFC 2047
        // encoded-word and therefore must not decode back.
        let result = RFC2047Coder.encode("")
        XCTAssertEqual(result, "=?utf-8?b??=",
                       "Encoder produces a wrapper with empty payload for empty input")
        XCTAssertNil(RFC2047Coder.decode("=?utf-8?b??="),
                     "Decoder must reject empty encoded-text per RFC 2047 §2 (1* repetition)")
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
        // RFC 2047 §2: encoded-text = 1*<Any printable ASCII char other
        // than "?" or SPACE>. Cover both encoding paths so a regression
        // that relaxes the regex but leaves the alphabet check would
        // still trip — the base64 case happens to also fail because
        // SPACE isn't in the base64 alphabet, but that's incidental, so
        // the Q-encoding case below is the one that exercises the §2
        // SPACE-in-encoded-text rule directly.
        XCTAssertNil(RFC2047Coder.decode("=?utf-8?b?dGVz dA?="),
                     "SPACE in Base64 encoded-text must be rejected per RFC 2047 §2")
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q?ab cd?="),
                     "SPACE in Q encoded-text must be rejected per RFC 2047 §2 (Q alphabet would otherwise allow letters)")
    }

    // MARK: - Bug 1: RFC 2047 75-character limit

    func testDecode75CharLimitEnforced() {
        // RFC 2047 §2: "An 'encoded-word' may not be more than 75 characters long".
        // Overhead: "=?iso-8859-1?q?" (15) + "?=" (2) = 17 chars → 58 chars of content hits 75 exactly.
        let prefix = "=?iso-8859-1?q?"
        let suffix = "?="
        let overhead = prefix.count + suffix.count  // 17

        // Exactly 75 chars → accepted
        let content75 = String(repeating: "a", count: 75 - overhead)
        let encoded75 = prefix + content75 + suffix
        XCTAssertEqual(encoded75.count, 75)
        XCTAssertNotNil(RFC2047Coder.decode(encoded75),
                        "Encoded word of exactly 75 chars must be accepted per RFC 2047 §2")

        // 76 chars → must be rejected (was incorrectly accepted before the fix)
        let content76 = String(repeating: "a", count: 76 - overhead)
        let encoded76 = prefix + content76 + suffix
        XCTAssertEqual(encoded76.count, 76)
        XCTAssertNil(RFC2047Coder.decode(encoded76),
                     "Encoded word of 76 chars must be rejected per RFC 2047 §2 (max is 75)")
    }

    func testDecodeGreedyRegexNoExtraContent() {
        // The RFC2047 regex uses (.*) which is greedy. For "=?utf-8?b?aGVsbG8=?=extra?=",
        // the greedy match captures "aGVsbG8=?=extra" as the encoded text. The '?' character
        // is not in the base64 alphabet, so Data(base64Encoded:) returns nil, and decode must fail.
        // This guards against a scenario where extra content appended after the encoded-word
        // could be silently accepted.
        XCTAssertNil(RFC2047Coder.decode("=?utf-8?b?aGVsbG8=?=extra?="),
                     "Encoded word with trailing extra content separated by ?= should fail to decode")
        // Verify the clean version decodes correctly (aGVsbG8= is "hello" in base64)
        XCTAssertEqual(RFC2047Coder.decode("=?utf-8?b?aGVsbG8=?="), "hello",
                       "Clean base64 encoded word should decode correctly")
    }

    // MARK: - Encoder output structure
    //
    // Round-trip tests above only assert encode-then-decode equality, which
    // would also pass if `encode` produced any reversible blob. These tests
    // pin the *structural* shape of the output (`=?utf-8?b?…?=`) so a future
    // change that, say, switched to a different charset/encoding triplet or
    // emitted padding `=` would break loudly here, not silently downstream
    // (e.g. interop with strict RFC 2047 parsers in third-party MTAs).

    func testEncodeOutputAlwaysUsesUtf8BasePrefix() {
        let inputs = [
            "user@domain.com",       // pure ASCII
            "用户@example.com",       // CJK
            "café@bistro.fr",        // Latin-1 supplement
            "한@x.한국",               // Hangul + IDN
            ""                       // empty
        ]
        for input in inputs {
            guard let encoded = RFC2047Coder.encode(input) else {
                XCTFail("Encoder must not return nil for valid UTF-8 input: '\(input)'")
                continue
            }
            XCTAssertTrue(encoded.hasPrefix("=?utf-8?b?"),
                          "Encoded form must start with `=?utf-8?b?` (got: '\(encoded)')")
            XCTAssertTrue(encoded.hasSuffix("?="),
                          "Encoded form must end with `?=` (got: '\(encoded)')")
            XCTAssertFalse(encoded.dropFirst("=?utf-8?b?".count).dropLast(2).contains("="),
                           "Encoded base64 payload must not contain `=` padding — encoder strips it (got: '\(encoded)')")
        }
    }

    func testEncodedPayloadIsValidBase64Alphabet() {
        guard let encoded = RFC2047Coder.encode("用户@example.com") else {
            XCTFail("Encoder failed for CJK input")
            return
        }
        let prefix = "=?utf-8?b?"
        let suffix = "?="
        XCTAssertTrue(encoded.hasPrefix(prefix) && encoded.hasSuffix(suffix))
        let payload = encoded.dropFirst(prefix.count).dropLast(suffix.count)
        // RFC 4648 §4 base64 alphabet: A-Z a-z 0-9 + /. The encoder strips '='.
        let allowed: Set<Character> = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
        XCTAssertTrue(payload.allSatisfy { allowed.contains($0) },
                      "Encoded payload must contain only base64 alphabet characters (got: '\(payload)')")
    }

    // MARK: - ISO-8859-2 multi-character Q-decode round-trip
    //
    // The Latin-2-specific decode tests above each cover a single hex byte.
    // This test exercises a longer Q-encoded string carrying multiple
    // ISO-8859-2-specific scalars (Polish, Czech, Hungarian, Romanian) to
    // catch any byte-walking or per-character-state regressions in the
    // decoder loop. (`encode()` only emits UTF-8 base64, so there is no true
    // encode-then-decode round-trip path for ISO-8859-2 — this test is the
    // closest analog.)
    func testDecodingLatin2QMultiCharRoundTrip() {
        // Polish ą (0xB1), ć (0xE6), ę (0xEA), ł (0xB3), ń (0xF1), ó (0xF3),
        // ś (0xB6), ź (0xBC), ż (0xBF) + Czech ě (0xEC), ř (0xF8), č (0xE8),
        // š (0xB9), ž (0xBE) + Hungarian ő (0xF5), ű (0xFB).
        let encoded = "=?iso-8859-2?q?=B1=E6=EA=B3=F1=F3=B6=BC=BF=EC=F8=E8=B9=BE=F5=FB?="
        XCTAssertEqual(RFC2047Coder.decode(encoded), "ąćęłńóśźżěřčšžőű",
                       "Multi-character ISO-8859-2 Q-encoded string must decode to expected Unicode")
    }

    // MARK: - UTF-16 / UTF-32 BOM-less payload behavior
    //
    // The encoder always emits UTF-8, so BOM handling is a decoder-side concern
    // for inbound payloads from other encoders. Foundation's
    // `String(data:encoding:.utf16/.utf32)` falls back to platform-endian
    // when no BOM is present. These tests document *that* behavior — if it
    // ever changes (e.g. a future Swift release rejects BOM-less UTF-16/-32
    // outright), this test surfaces the breaking change.
    //
    // We use big-endian byte sequences and accept either a successful decode
    // (platform happens to be BE) OR nil/replacement-char output (platform is
    // LE and reads the bytes as garbled scalars). The point is the decoder
    // doesn't crash and behavior is consistent with Foundation's contract.

    func testDecodingUTF16BomlessBehaviorDocumented() {
        // "test" as UTF-16 big-endian without BOM: 00 74 00 65 00 73 00 74
        let bomlessUtf16BE = Data([0x00, 0x74, 0x00, 0x65, 0x00, 0x73, 0x00, 0x74])
        let base64 = bomlessUtf16BE.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let encoded = "=?utf-16?b?\(base64)?="
        let result = RFC2047Coder.decode(encoded)
        // Platform-endian dependent: on BE platforms (rare today) decodes to "test";
        // on LE platforms (typical) Foundation reads as bytes 7400 → U+7400 (CJK), etc.
        // Either way, decoding must not crash, and a successful decode must yield
        // a non-empty, valid String. We do not pin the value.
        if let result = result {
            XCTAssertFalse(result.isEmpty,
                           "BOM-less UTF-16 must not decode to empty when Foundation accepts it")
        }
        // Sanity: same payload with BOM prepended decodes deterministically.
        let withBom = Data([0xFE, 0xFF]) + bomlessUtf16BE
        let base64WithBom = withBom.base64EncodedString().replacingOccurrences(of: "=", with: "")
        XCTAssertEqual(RFC2047Coder.decode("=?utf-16?b?\(base64WithBom)?="), "test",
                       "UTF-16BE with BOM must decode deterministically to 'test'")
    }

    func testDecodingUTF32BomlessBehaviorDocumented() {
        // "hi" as UTF-32 big-endian without BOM: 00 00 00 68 00 00 00 69
        let bomlessUtf32BE = Data([0x00, 0x00, 0x00, 0x68, 0x00, 0x00, 0x00, 0x69])
        let base64 = bomlessUtf32BE.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let encoded = "=?utf-32?b?\(base64)?="
        let result = RFC2047Coder.decode(encoded)
        // Platform-endian dependent — see UTF-16 test above for rationale.
        if let result = result {
            XCTAssertFalse(result.isEmpty,
                           "BOM-less UTF-32 must not decode to empty when Foundation accepts it")
        }
        // Sanity: same payload with BOM prepended decodes deterministically.
        let withBom = Data([0x00, 0x00, 0xFE, 0xFF]) + bomlessUtf32BE
        let base64WithBom = withBom.base64EncodedString().replacingOccurrences(of: "=", with: "")
        XCTAssertEqual(RFC2047Coder.decode("=?utf-32?b?\(base64WithBom)?="), "hi",
                       "UTF-32BE with BOM must decode deterministically to 'hi'")
    }

    // MARK: - C1 control byte rejection in Q-encoded ISO-8859-1/2

    func testDecodingLatin1QC1ControlBytesRejected() {
        // C1 control bytes (0x80–0x9F) must be rejected from Q-encoded ISO-8859-1/2 words.
        // They are not valid interchange characters and must not decode to C1 Unicode scalars.
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q?=80?="),
                     "0x80 (first C1 control) must be rejected from Q-encoded ISO-8859-1")
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q?=90?="),
                     "0x90 (C1 control mid-range) must be rejected from Q-encoded ISO-8859-1")
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q?=9F?="),
                     "0x9F (last C1 control) must be rejected from Q-encoded ISO-8859-1")
        // 0xA0 is the first byte above the C1 range (non-breaking space in ISO-8859-1) and must pass
        XCTAssertNotNil(RFC2047Coder.decode("=?iso-8859-1?q?=A0?="),
                        "0xA0 (non-breaking space, first byte above C1 range) must be accepted")
    }

    func testDecodingRejectsEmptyEncodedText() {
        // RFC 2047 §2: encoded-text = 1*<Any printable ASCII char other than "?" or SPACE>.
        // An empty encoded-text segment is malformed by definition.
        XCTAssertNil(RFC2047Coder.decode("=?utf-8?b??="),
                     "Empty Base64 encoded-text must be rejected per RFC 2047 §2 (1* repetition)")
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q??="),
                     "Empty Q encoded-text must be rejected per RFC 2047 §2 (1* repetition)")
    }

    func testDecodingRejectsLiteralQuestionMarkInEncodedText() {
        // RFC 2047 §2: '?' is the segment delimiter and is forbidden inside encoded-text.
        // The prior `(.*)` regex would greedily backtrack and produce decoded
        // payloads containing a literal '?' (e.g. "ab?cd").
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q?ab?cd?="),
                     "Literal '?' inside Q encoded-text must be rejected per RFC 2047 §2")
        XCTAssertNil(RFC2047Coder.decode("=?utf-8?b?YQ?Yg?="),
                     "Literal '?' inside Base64 encoded-text must be rejected per RFC 2047 §2")
    }

    func testDecodingRejectsSpaceInEncodedText() {
        // RFC 2047 §2 also bars literal SPACE from encoded-text. Q-encoders
        // must use '_' or '=20' instead. The new `[^? ]+` group enforces this.
        XCTAssertNil(RFC2047Coder.decode("=?iso-8859-1?q?ab cd?="),
                     "Literal SPACE inside Q encoded-text must be rejected per RFC 2047 §2")
    }
}
