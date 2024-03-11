//
//  EmailSyntaxValidator.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-21.
//  Copyrights (C) 2022, Dave Poirier.  Distributed under MIT license
//
//  References:
//  * RFC2047 https://datatracker.ietf.org/doc/html/rfc2047
//  * RFC5321 https://datatracker.ietf.org/doc/html/rfc5321 Section 4.1.2 & Section 4.1.3
//  * RFC5322 https://datatracker.ietf.org/doc/html/rfc5322 Section 3.2.3 & Section 3.4.1
//  * RFC5234 https://datatracker.ietf.org/doc/html/rfc5234 Appendix B.1
//  * RFC6531 https://datatracker.ietf.org/doc/html/rfc6531

import Foundation
import SwiftPublicSuffixList

public final class EmailSyntaxValidator {
    
    public struct Mailbox {
        public let email: String
        public let localPart: LocalPart
        public let host: Host

        public enum LocalPart: Equatable {
            case dotAtom(String)
            case quotedString(String)
        }
        
        public enum Host: Equatable {
            case domain(String)
            case addressLiteral(String)
        }
    }
    
    public enum Options: Equatable {
        case autoEncodeToRfc2047 // If using .asciiWithUnicodeExtension and string is in Unicode, will auto encode using RFC2047
    }
    
    public enum Compatibility {
        case ascii
        case asciiWithUnicodeExtension
        case unicode
    }
    
    /// Verify if the email address is correctly formatted
    /// - Parameters:
    ///   - candidate: String to validate
    ///   - strategy: (Optional) ValidationStrategy to use, use .strict for strict validation or use .autoEncodeToRfc2047 for some auto-formatting flexibility, Uses .strict by default.
    ///   - compatibility: (Optional) Compatibility required, one of .ascii (RFC822), .asciiWithUnicodeExtension (RFC2047) or .unicode (RFC6531). Uses .unicode by default.
    ///   - allowAddressLiteral: (Optional) True to allow IPv4 & IPv6 instead of domains in email addresses, false otherwise. False by default.
    ///   - domainValidator: Non-escaping closure that return true if the domain should be considered valid or false to be rejected
    /// - Returns: True if syntax is valid (.smtpHeader validation strategy) or could be adapted to be valid (.userInterface validation strategy)
    public static func correctlyFormatted(_ candidate: String,
                                          options: [Options] = [],
                                          compatibility: Compatibility = .unicode,
                                          allowAddressLiteral: Bool = false,
                                          domainValidator: (String) -> Bool = { PublicSuffixList.isUnrestricted($0) }) -> Bool {

        mailbox(from: candidate,
                options: options,
                compatibility: compatibility,
                allowAddressLiteral: allowAddressLiteral,
                domainValidator: domainValidator) != nil
    }
    
    /// Attempt to extract the Local and Remote parts of the email address specified
    /// - Parameters:
    ///   - candidate: String to validate
    ///   - strategy: (Optional) ValidationStrategy to use, use .smtpHeader for strict validation or use UI strategy for some auto-formatting flexibility, Uses .smtpHeader by default.
    ///   - compatibility: (Optional) Compatibility required, one of .ascii (RFC822), .asciiWithUnicodeExtension (RFC2047) or .unicode (RFC6531). Uses .unicode by default.
    ///   - allowAddressLiteral: (Optional) True to allow IPv4 & IPv6 instead of domains in email addresses, false otherwise. False by default.
    ///   - domainValidator: Non-escaping closure that return true if the domain should be considered valid or false to be rejected
    /// - Returns: Mailbox struct on success, nil otherwise
    public static func mailbox(from candidate: String,
                               options: [Options] = [],
                               compatibility: Compatibility = .unicode,
                               allowAddressLiteral: Bool = false,
                               domainValidator: (String) -> Bool = { PublicSuffixList.isUnrestricted($0) }) -> Mailbox? {
        
        var smtpCandidate: String = candidate
        var extractionCompatibility: Compatibility = compatibility
        if compatibility != .ascii {
            if let decodedCandidate = RFC2047Coder.decode(candidate) {
                smtpCandidate = decodedCandidate
                extractionCompatibility = .unicode
            } else {
                // Failed RFC2047 SMTP Unicode Extension decoding, fallback to ASCII or full Unicode
                extractionCompatibility = (compatibility == .asciiWithUnicodeExtension ? .ascii : .unicode)
            }
        }

        if let dotAtom = extractDotAtom(smtpCandidate, compatibility: extractionCompatibility) {
            return mailbox(
                localPart: .dotAtom(dotAtom),
                originalCandidate: candidate,
                hostCandidate: String(smtpCandidate.dropFirst(dotAtom.count + 1)),
                allowAddressLiteral: allowAddressLiteral,
                domainValidator: domainValidator)
        }
        
        if let quotedString = extractQuotedString(smtpCandidate, compatibility: extractionCompatibility) {
            return mailbox(
                localPart: .quotedString(String(quotedString.cleaned)),
                originalCandidate: candidate,
                hostCandidate: String(smtpCandidate.dropFirst(quotedString.integral.count + 1)),
                allowAddressLiteral: allowAddressLiteral,
                domainValidator: domainValidator)
        }
        
        if options.contains(.autoEncodeToRfc2047), let rfc2047candidate = candidateForRfc2047(candidate, compatibility: compatibility) {
            return mailbox(
                from: rfc2047candidate,
                options: [],
                compatibility: compatibility,
                allowAddressLiteral: allowAddressLiteral,
                domainValidator: domainValidator)
        }
        
        return nil
    }
    
    /// Attempt to repackage a Unicode email into an RFC2047 encoded email (will return nil if string doesn't contain Unicode characters)
    /// - Parameters:
    ///   - candidate: String that originally failed SMTP validation that should be RFC2047 encoded if possible
    ///   - compatibility: Required compatibility level
    /// - Returns: Repackaged email string (may still fail SMTP validation) or nil if really nothing that could be done
    private static func candidateForRfc2047(_ candidate: String, compatibility: Compatibility) -> String? {
        
        guard compatibility == .asciiWithUnicodeExtension,
              !candidate.hasPrefix("=?"),
              candidate.rangeOfCharacter(from: qtextUnicodeSMTPCharacterSet.inverted) == nil
        else {
            // There are some unsupported ASCII characters which are invalid regardless of unicode or ASCII (newline, tabs, etc)
            return nil
        }

        guard candidate.rangeOfCharacter(from: CharacterSet(charactersIn: asciiRange).inverted) != nil else {
            // There are no Unicode characters to encode, so the string was already validated to the maximum extent allowed
            return nil
        }
        
        // Some non-ASCII characters are present, and we can RFC2047 encode it
        return RFC2047Coder.encode(candidate)
    }
    
    private static func mailbox(localPart: Mailbox.LocalPart, originalCandidate: String, hostCandidate: String, allowAddressLiteral: Bool, domainValidator: (String) -> Bool) -> Mailbox? {
        
        guard let host = extractHost(from: hostCandidate, allowAddressLiteral: allowAddressLiteral, domainValidator: domainValidator) else {
            return nil
        }
        
        return Mailbox(
            email: originalCandidate,
            localPart: localPart,
            host: host)
    }
    
    private static func extractHost(from candidate: String, allowAddressLiteral: Bool, domainValidator: (String) -> Bool) -> Mailbox.Host? {

        if candidate.hasPrefix("[") {
            return extractHostLiteral(from: candidate, allowAddressLiteral: allowAddressLiteral)
        }

        if domainValidator(candidate) {
            return .domain(candidate)
        }
        
        return nil
    }
    
    private static func extractHostLiteral(from candidate: String, allowAddressLiteral: Bool) -> Mailbox.Host? {
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
