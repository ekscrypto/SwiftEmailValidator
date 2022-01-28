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
        case userInterface // will validate email can be encoded to desired smtp compatibility
    }
    
    public enum Compatibility {
        case ascii
        case asciiWithUnicodeExtension
        case unicode
    }
    
    /// Verify if the email address is correctly formatted
    /// - Parameters:
    ///   - candidate: String to validate
    ///   - strategy: (Optional) ValidationStrategy to use, use .smtpHeader for strict validation or use UI strategy for some auto-formatting flexibility, Uses .smtpHeader by default.
    ///   - compatibility: (Optional) Compatibility required, one of .ascii (RFC822), .asciiWithUnicodeExtension (RFC2047) or .unicode (RFC6531). Uses .unicode by default.
    ///   - allowAddressLiteral: (Optional) True to allow IPv4 & IPv6 instead of domains in email addresses, false otherwise. False by default.
    ///   - domainRules: (Optional) Public Suffix rules to apply to domain validation.  Uses Public Suffix List by default.
    /// - Returns: True if syntax is valid (.smtpHeader validation strategy) or could be adapted to be valid (.userInterface validation strategy)
    public static func correctlyFormatted(_ candidate: String,
                                          strategy: ValidationStrategy = .smtpHeader,
                                          compatibility: Compatibility = .unicode,
                                          allowAddressLiteral: Bool = false,
                                          domainRules: [[String]] = PublicSuffixRulesRegistry.rules) -> Bool {

        mailbox(from: candidate,
                strategy: strategy,
                compatibility: compatibility,
                allowAddressLiteral: allowAddressLiteral,
                domainRules: domainRules) != nil
    }
    
    /// Attempt to extract the Local and Remote parts of the email address specified
    /// - Parameters:
    ///   - candidate: String to validate
    ///   - strategy: (Optional) ValidationStrategy to use, use .smtpHeader for strict validation or use UI strategy for some auto-formatting flexibility, Uses .smtpHeader by default.
    ///   - compatibility: (Optional) Compatibility required, one of .ascii (RFC822), .asciiWithUnicodeExtension (RFC2047) or .unicode (RFC6531). Uses .unicode by default.
    ///   - allowAddressLiteral: (Optional) True to allow IPv4 & IPv6 instead of domains in email addresses, false otherwise. False by default.
    ///   - domainRules: (Optional) Public Suffix rules to apply to domain validation.  Uses Public Suffix List by default.
    /// - Returns: Mailbox struct on success, nil otherwise
    public static func mailbox(from candidate: String,
                               strategy: ValidationStrategy = .smtpHeader,
                               compatibility: Compatibility = .unicode,
                               allowAddressLiteral: Bool = false,
                               domainRules: [[String]] = PublicSuffixRulesRegistry.rules) -> Mailbox? {
        
        var smtpCandidate: String = candidate
        if compatibility != .ascii, let decodedCandidate = RFC2047Coder.decode(candidate) {
            smtpCandidate = decodedCandidate
        }

        let localPart: Mailbox.LocalPart
        let nonLocalPart: String
        if let dotAtom = extractDotAtom(smtpCandidate, compatibility: compatibility) {
            localPart = .dotAtom(dotAtom)
            nonLocalPart = String(smtpCandidate.dropFirst(dotAtom.count + 1))
        } else if let quotedString = extractQuotedString(smtpCandidate, compatibility: compatibility) {
            localPart = .quotedString(String(quotedString.cleaned))
            nonLocalPart = String(smtpCandidate.dropFirst(quotedString.integral.count + 1))
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
    
    private static func extractHost(from candidate: String, allowAddressLiteral: Bool, domainRules: [[String]]) -> Mailbox.Host? {

        if candidate.hasPrefix("[") {
            guard allowAddressLiteral, candidate.hasSuffix("]") else {
                return nil
            }
            let addressLiteralCandidate = String(candidate.dropFirst().dropLast()) // get rid of [ and ]
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
    private static let asciiRange: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x00)!...Unicode.Scalar(0x7F)!
    private static let atextUnicodeCharacterSet: CharacterSet = atextCharacterSet
        .union(CharacterSet(charactersIn: asciiRange).inverted)
    private static let quotedPairSMTP: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x20)!...Unicode.Scalar(0x7E)!
    private static let qtextSMTP1: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x20)!...Unicode.Scalar(0x21)!
    private static let qtextSMTP2: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x23)!...Unicode.Scalar(0x5B)!
    private static let qtextSMTP3: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x5D)!...Unicode.Scalar(0x7E)!
    private static let qtextSMTPCharacterSet: CharacterSet = CharacterSet(charactersIn: qtextSMTP1)
        .union(CharacterSet(charactersIn: qtextSMTP2))
        .union(CharacterSet(charactersIn: qtextSMTP3))
    private static let qtextUnicodeSMTPCharacterSet = qtextSMTPCharacterSet
        .union(CharacterSet(charactersIn: asciiRange).inverted)

    private static func extractDotAtom(_ candidate: String, compatibility: Compatibility) -> String? {
        guard !candidate.hasPrefix("\""),
              let atRange = candidate.range(of: "@")
        else {
            return nil
        }
        
        let dotAtom = candidate[..<atRange.lowerBound]
        let disallowedCharacterSet: CharacterSet = compatibility == .ascii ? atextCharacterSet.inverted : atextUnicodeCharacterSet.inverted
        guard dotAtom.count > 0,
              dotAtom.count <= 64,
              !dotAtom.hasPrefix("."),
              !dotAtom.hasSuffix("."),
              dotAtom.components(separatedBy: ".").allSatisfy({ $0.count > 0 && $0.rangeOfCharacter(from: disallowedCharacterSet) == nil })
        else {
            return nil
        }
        return String(dotAtom)
    }
    
    private struct ExtractedQuotedText {
        let integral: String
        let cleaned: String
    }
    
    private static func extractQuotedString(_ candidate: String, compatibility: Compatibility) -> ExtractedQuotedText? {
        guard candidate.hasPrefix("\"") else {
            return nil
        }
        var cleanedText: String = ""
        var integralText: String = ""
        var escaped: Bool = false
        var dquotes: Int = 0
        var expectingAt: Bool = false
        
        let allowedCharacterSet: CharacterSet = compatibility == .ascii ? qtextSMTPCharacterSet :  qtextUnicodeSMTPCharacterSet
        let maxScalars: Int = compatibility == .ascii ? 1 : 5
        
    nextCharacter:
        for character in candidate {
            precondition(dquotes <= 2)
            guard let characterScalar = character.unicodeScalars.first,
                  character.unicodeScalars.count <= maxScalars
            else {
                return nil
            }
            
            if expectingAt {
                guard character == "@" else {
                    return nil
                }
                return ExtractedQuotedText(integral: integralText, cleaned: cleanedText)
            }
            
            integralText.append(character)
            
            if escaped {
                cleanedText.append(character)
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

            cleanedText.append(character)
            
            guard String(character).rangeOfCharacter(from: allowedCharacterSet) != nil else {
                return nil
            }
        }
        return nil
    }
}
