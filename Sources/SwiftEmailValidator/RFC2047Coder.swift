//
//  RFC2047Coder.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-22.
//  Copyrights (C) 2022, Dave Poirier.  Distributed under MIT license
//
//  References:
//  * RFC2047 https://datatracker.ietf.org/doc/html/rfc2047

import Foundation

/// Encodes and decodes email addresses using RFC 2047 MIME encoding.
///
/// RFC 2047 allows non-ASCII characters to be represented in email headers using
/// ASCII-compatible encoding. This is useful for international email addresses
/// on systems that only support ASCII transport.
///
/// ## Supported Encodings
/// - Base64 ('b' encoding) for UTF-8, UTF-16, and UTF-32
/// - Quoted-Printable ('q' encoding) for ISO-8859-1 and ISO-8859-2
///
/// ## Usage
/// ```swift
/// // Encode a Unicode email address
/// let encoded = RFC2047Coder.encode("用户@example.com")
/// // Returns: "=?utf-8?b?55So5oi3QGV4YW1wbGUuY29t?="
///
/// // Decode an RFC 2047 encoded string
/// let decoded = RFC2047Coder.decode("=?utf-8?b?55So5oi3?=")
/// // Returns: "用户"
/// ```
public final class RFC2047Coder {
    
    private static let supportedEncoding: [String: String.Encoding] = [
        "utf-8": .utf8,
        "utf-16": .utf16,
        "utf-32": .utf32,
        "iso-8859-1": .isoLatin1,
        "iso-8859-2": .isoLatin2
    ]
    private static let digitValueTable: [Character: UInt8] = [
        "0": 0,
        "1": 1,
        "2": 2,
        "3": 3,
        "4": 4,
        "5": 5,
        "6": 6,
        "7": 7,
        "8": 8,
        "9": 9,
        "a": 10,
        "b": 11,
        "c": 12,
        "d": 13,
        "e": 14,
        "f": 15,
        "A": 10,
        "B": 11,
        "C": 12,
        "D": 13,
        "E": 14,
        "F": 15
    ]
    private static let rfc2047regex = #"^=\?([A-Za-z0-9-]+)\?([bBqQ])\?(.*)\?=$"#

    /// Decodes an RFC 2047 encoded string.
    ///
    /// - Parameter encoded: The RFC 2047 encoded string in the format `=?charset?encoding?text?=`
    /// - Returns: The decoded string, or `nil` if decoding fails or the input is not valid RFC 2047 format
    ///
    /// ## Supported Formats
    /// - Base64 encoding (`b`): `=?utf-8?b?base64text?=`
    /// - Quoted-Printable encoding (`q`): `=?iso-8859-1?q?quoted=20text?=`
    ///
    /// ## Limitations
    /// - Maximum input length: 76 characters (per RFC 2047)
    /// - Quoted-Printable only supports ISO-8859-1 and ISO-8859-2 charsets
    public static func decode(_ encoded: String) -> String? {
        
        guard encoded.count <= 76 else {
            return nil
        }
        let encodingComponents = match(regex: rfc2047regex, to: encoded)
        guard let match = encodingComponents.first, match.count == 4 else {
            return nil
        }
        let charset = match[1].lowercased()
        let encoding = match[2].lowercased()
        let encodedText = match[3]
        guard let stringEncoding = supportedEncoding[charset] else {
            return nil
        }
        
        if encoding == "b" {
            let padding: [String] = ["", "===", "==", "="]
            let paddedEncodedText = "\(encodedText)\(padding[encodedText.count % 4])"
            
            guard let encodedTextData = Data(base64Encoded: paddedEncodedText),
                  let decoded = String(data: encodedTextData, encoding: stringEncoding)
            else {
                return nil
            }
            return decoded
        }

        assert(encoding == "q")
        guard [.isoLatin1, .isoLatin2].contains(stringEncoding) else {
            // rejects 'q' encoding for utf-8, should be 'b' encoded.
            return nil
        }
        var decoded = ""
        var value: UInt8 = 0
        var lookingForMarker: Bool = true
        var digitsCaptured: Int = 0
        
    nextCharacter:
        for character in encodedText {
            if lookingForMarker {
                if character == "=" {
                    lookingForMarker = false
                    digitsCaptured = 0
                    value = 0
                    continue nextCharacter
                }
                decoded.append(character)
                continue nextCharacter
            }
            
            guard let digitValue = digitValueTable[character] else {
                return nil
            }
            value = (value << 4) | digitValue
            digitsCaptured += 1
            if digitsCaptured == 1 { continue nextCharacter }
            
            guard value >= 0x20,
                  value != 0xFF,
                  let decodedCharacter = String(data: Data([value]), encoding: stringEncoding)
            else {
                return nil
            }

            decoded.append(decodedCharacter)
            lookingForMarker = true
        }
        guard lookingForMarker else {
            return nil
        }
        return decoded
    }

    /// Encodes a string using RFC 2047 Base64 encoding with UTF-8 charset.
    ///
    /// - Parameter candidate: The string to encode
    /// - Returns: The RFC 2047 encoded string in the format `=?utf-8?b?base64text?=`, or `nil` if encoding fails
    ///
    /// ## Example
    /// ```swift
    /// let encoded = RFC2047Coder.encode("用户")
    /// // Returns: "=?utf-8?b?55So5oi3?="
    /// ```
    public static func encode(_ candidate: String) -> String? {
        guard let utf8data = candidate.data(using: .utf8) else {
            return nil
        }
        let base64 = utf8data.base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        return "=?utf-8?b?\(base64)?="
    }
    
    private static func match(regex: String, to value: String) -> [[String]] {
        let nsValue: NSString = value as NSString
        return (try? NSRegularExpression(pattern: regex, options: []))?.matches(in: value, options: [], range: NSMakeRange(0, nsValue.length)).map { match in
            (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : nsValue.substring(with: match.range(at: $0)) }
        } ?? []
    }
}
