//
//  EmailSyntaxValidator.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-21.
//  Copyrights (C) 2022, Dave Poirier.  Distributed under MIT license
//
//  References:
//  * RFC5321 https://datatracker.ietf.org/doc/html/rfc5321 Section 4.1.2 & Section 4.1.3
//  * RFC5322 https://datatracker.ietf.org/doc/html/rfc5322 Section 3.2.3 & Section 3.4.1
//  * RFC5234 https://datatracker.ietf.org/doc/html/rfc5234 Appendix B.1

import Foundation

public final class EmailSyntaxValidator {
    
    public struct Mailbox {
        let localPart: LocalPart
        let host: Host

        public enum LocalPart: Equatable {
            case dotAtom(String)
            case quotedString(String)
        }
        
        public enum Host: Equatable {
            case domain(String)
            case addressLiteral(String)
        }
    }
    
    public enum ValidationStrategy {
        case smtpHeader // will detect and decode =? encoded email addresses
        case userInterface
    }
    
    public static func match(_ candidate: String, strategy: ValidationStrategy = .smtpHeader, allowAddressLiteral: Bool = false, domainRules: [[String]] = PublicSuffixRulesRegistry.rules) -> Bool {
        mailbox(from: candidate, allowAddressLiteral: allowAddressLiteral, domainRules: domainRules) != nil
    }
    
    public static func mailbox(from candidate: String, strategy: ValidationStrategy = .smtpHeader, allowAddressLiteral: Bool = false, domainRules: [[String]] = PublicSuffixRulesRegistry.rules) -> Mailbox? {
        
        let localPart: Mailbox.LocalPart
        let nonLocalPart: String
        if let dotAtom = extractDotAtom(candidate) {
            localPart = .dotAtom(dotAtom)
            nonLocalPart = String(candidate.dropFirst(dotAtom.count + 1))
        } else if let quotedString = extractQuotedString(candidate) {
            localPart = .quotedString(quotedString)
            nonLocalPart = String(candidate.dropFirst(quotedString.count + 1))
        } else if strategy == .smtpHeader, let decodedCandidate = RFC2047Coder.decode(candidate) {
            if let unicodeDotAtom = extractUnicodeDotAtom(candidate) {
                localPart = .dotAtom(unicodeDotAtom)
                nonLocalPart = String(decodedCandidate.dropFirst(unicodeDotAtom.count + 1))
            } else if let unicodeQuotedString = extractUnicodeQuotedString(decodedCandidate) {
                localPart = .quotedString(unicodeQuotedString)
                nonLocalPart = String(decodedCandidate.dropFirst(unicodeQuotedString.count + 1))
            } else {
                return nil
            }
        } else {
            return nil
        }

        guard let host = extractHost(from: nonLocalPart, allowAddressLiteral: allowAddressLiteral, domainRules: domainRules) else {
            return nil
        }
        
        return Mailbox(
            localPart: localPart,
            host: host)
    }
    
    private static func extractUnicodeDotAtom(_ candidate: String) -> String? {
        nil
    }
    
    private static func extractUnicodeQuotedString(_ candidate: String) -> String? {
        nil
    }
    
    private static func extractHost(from candidate: String, allowAddressLiteral: Bool, domainRules: [[String]]) -> Mailbox.Host? {

        if candidate.hasPrefix("[") {
            guard allowAddressLiteral, candidate.hasSuffix("]") else {
                return nil
            }
            let addressLiteralCandidate = String(candidate.dropFirst().dropLast())
            let ipv6Tag = "IPv6" // ref: https://www.iana.org/assignments/address-literal-tags/address-literal-tags.xhtml
            
            if addressLiteralCandidate.hasPrefix("\(ipv6Tag):"), IPAddressSyntaxValidator.matchIPv6(String(addressLiteralCandidate.dropFirst(ipv6Tag.count + 1))) {
                return .addressLiteral(addressLiteralCandidate)
            }
            
            guard IPAddressSyntaxValidator.matchIPv4(addressLiteralCandidate) else {
                return nil
            }
            return .addressLiteral(addressLiteralCandidate)
        }

        guard EmailHostSyntaxValidator.match(candidate, rules: domainRules) else {
            return nil
        }
        return .domain(candidate)
    }

    private static let digitRange: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x30)!...Unicode.Scalar(0x39)! // 0-9
    private static let alphaUpperRange: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x41)!...Unicode.Scalar(0x5A)! // A-Z
    private static let alphaLowerRange: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x61)!...Unicode.Scalar(0x7A)! // a-z
    private static let atextCharacterSet: CharacterSet = CharacterSet(charactersIn: alphaLowerRange)
        .union(CharacterSet(charactersIn: alphaUpperRange))
        .union(CharacterSet(charactersIn: digitRange))
        .union(CharacterSet(charactersIn: #"!#$%&'*+-/=?^_`{|}~"#)) // Ref RFC5322 section 3.2.3 Atom, definition of atext
    private static let quotedPairSMTP: ClosedRange<Unicode.Scalar> = Unicode.Scalar(32)!...Unicode.Scalar(126)!
    private static let qtextSMTP1: ClosedRange<Unicode.Scalar> = Unicode.Scalar(32)!...Unicode.Scalar(33)!
    private static let qtextSMTP2: ClosedRange<Unicode.Scalar> = Unicode.Scalar(35)!...Unicode.Scalar(91)!
    private static let qtextSMTP3: ClosedRange<Unicode.Scalar> = Unicode.Scalar(93)!...Unicode.Scalar(126)!
    private static let qtextSMTPCharacterSet: CharacterSet = CharacterSet(charactersIn: qtextSMTP1)
        .union(CharacterSet(charactersIn: qtextSMTP2))
        .union(CharacterSet(charactersIn: qtextSMTP3))

    private static func extractDotAtom(_ candidate: String) -> String? {
        guard !candidate.hasPrefix("\""),
              let atRange = candidate.range(of: "@")
        else {
            return nil
        }
        
        let dotAtom = candidate[..<atRange.lowerBound]
        guard dotAtom.count > 0,
              dotAtom.count <= 64,
              !dotAtom.hasPrefix("."),
              !dotAtom.hasSuffix("."),
              dotAtom.components(separatedBy: ".").allSatisfy({ $0.count > 0 && $0.rangeOfCharacter(from: atextCharacterSet.inverted) == nil })
        else {
            return nil
        }
        return String(dotAtom)
    }
    
    private static func extractQuotedString(_ candidate: String) -> String? {
        guard candidate.hasPrefix("\"") else {
            return nil
        }
        var quotedText: String = ""
        var escaped: Bool = false
        var dquotes: Int = 0
        var expectingAt: Bool = false
        
    nextCharacter:
        for character in candidate {
            precondition(dquotes <= 2)
            guard let characterScalar = character.unicodeScalars.first,
                  character.unicodeScalars.count == 1
            else {
                return nil
            }
            
            if expectingAt {
                guard character == "@" else {
                    return nil
                }
                return quotedText
            }
            
            quotedText.append(character)
            
            if escaped {
                guard quotedPairSMTP.contains(characterScalar) else {
                    return nil
                }
                escaped = false
                continue nextCharacter
            }
            
            if character == "\\" {
                escaped = true
                continue nextCharacter
            }

            if character == "\"" {
                dquotes += 1
                if dquotes == 2 {
                    expectingAt = true
                }
                continue nextCharacter
            }

            guard qtextSMTPCharacterSet.contains(characterScalar) else {
                return nil
            }
        }
        return nil
    }
}
