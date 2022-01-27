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
            guard let encodedTextData = Data(base64Encoded: Base64Padder.pad(encodedText)),
                  let decoded = String(data: encodedTextData, encoding: stringEncoding)
            else {
                return nil
            }
            return decoded
        }

        assert(encoding == "q")
        guard [.isoLatin1, .isoLatin2].contains(stringEncoding) else {
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
    
    private static func match(regex: String, to value: String) -> [[String]] {
        let nsValue: NSString = value as NSString
        return (try? NSRegularExpression(pattern: regex, options: []))?.matches(in: value, options: [], range: NSMakeRange(0, nsValue.length)).map { match in
            (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : nsValue.substring(with: match.range(at: $0)) }
        } ?? []
    }
}
