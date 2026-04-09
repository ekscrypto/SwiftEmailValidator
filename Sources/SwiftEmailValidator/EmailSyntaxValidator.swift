//
//  EmailSyntaxValidator.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-21.
//  Copyrights (C) 2022, Dave Poirier.  Distributed under MIT license
//
//  References:
//  * RFC2047 https://datatracker.ietf.org/doc/html/rfc2047
//  * RFC5198 https://datatracker.ietf.org/doc/html/rfc5198 (Unicode Format for Network Interchange)
//  * RFC5321 https://datatracker.ietf.org/doc/html/rfc5321 Section 4.1.2 & Section 4.1.3
//  * RFC5322 https://datatracker.ietf.org/doc/html/rfc5322 Section 3.2.3 & Section 3.4.1
//  * RFC5234 https://datatracker.ietf.org/doc/html/rfc5234 Appendix B.1
//  * RFC6531 https://datatracker.ietf.org/doc/html/rfc6531
//  * RFC6532 https://datatracker.ietf.org/doc/html/rfc6532

import Foundation
import SwiftPublicSuffixList

/// An RFC-compliant email syntax validator supporting international email addresses.
///
/// `EmailSyntaxValidator` validates email format without requiring network access.
/// It supports three compatibility modes for different RFC standards:
/// - `.ascii`: RFC 5322 (traditional ASCII-only emails)
/// - `.asciiWithUnicodeExtension`: RFC 2047 (encoded Unicode for ASCII-only systems)
/// - `.unicode`: RFC 6531 (full internationalized email addresses)
///
/// ## Usage
/// ```swift
/// // Simple validation
/// let isValid = EmailSyntaxValidator.correctlyFormatted("user@example.com")
///
/// // Parse email into components
/// if let mailbox = EmailSyntaxValidator.mailbox(from: "user@example.com") {
///     print(mailbox.localPart) // .dotAtom("user")
///     print(mailbox.host)      // .domain("example.com")
/// }
/// ```
public final class EmailSyntaxValidator {

    /// A parsed email address containing the local part and host components.
    ///
    /// A `Mailbox` represents a successfully validated email address that has been
    /// decomposed into its constituent parts according to RFC 5321.
    public struct Mailbox {
        /// The original email address string that was validated.
        public let email: String

        /// The local part of the email address (the portion before the `@` symbol).
        public let localPart: LocalPart

        /// The host part of the email address (the portion after the `@` symbol).
        public let host: Host

        /// The format of the local part of an email address.
        ///
        /// Per RFC 5321, the local part can be either a dot-atom (simple format like `user.name`)
        /// or a quoted string (allowing special characters like `"user name"`).
        public enum LocalPart: Equatable {
            /// A dot-atom format local part (e.g., `user.name`).
            case dotAtom(String)
            /// A quoted-string format local part (e.g., `"user name"`).
            case quotedString(String)
        }

        /// The format of the host part of an email address.
        ///
        /// Per RFC 5321, the host can be either a domain name or an address literal (IP address).
        public enum Host: Equatable {
            /// A domain name host (e.g., `example.com`).
            case domain(String)
            /// An IP address literal host (e.g., `192.168.1.1` or `IPv6:2001:db8::1`).
            case addressLiteral(String)
        }
    }
    
    /// Validation options that modify the behavior of email validation.
    public enum Options: Equatable {
        /// Automatically encode Unicode email addresses using RFC 2047 when using `.asciiWithUnicodeExtension` compatibility.
        ///
        /// When this option is enabled and the input contains Unicode characters that cannot be
        /// validated as-is with `.asciiWithUnicodeExtension` compatibility, the validator will
        /// attempt to encode the email using RFC 2047 before validation.
        case autoEncodeToRfc2047
    }

    /// The RFC compatibility mode for email validation.
    ///
    /// Different email systems support different character sets. Use the appropriate
    /// compatibility mode based on your target system's capabilities.
    public enum Compatibility {
        /// ASCII-only validation per RFC 5322.
        ///
        /// Only allows characters in the ASCII range (0x00-0x7F) in the local part.
        /// Use this for maximum compatibility with legacy email systems.
        case ascii

        /// ASCII with RFC 2047 encoded Unicode extension.
        ///
        /// Allows Unicode characters that have been encoded using RFC 2047 MIME encoding.
        /// This enables international characters on systems that only support ASCII transport.
        case asciiWithUnicodeExtension

        /// Full Unicode support per RFC 6531 (SMTPUTF8).
        ///
        /// Allows Unicode characters directly in the email address without encoding.
        /// Requires SMTPUTF8-capable mail servers for delivery.
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

        // RFC 5321 §4.5.3.1.3: maximum total length of a reverse-path or forward-path is 256 octets (254 for the address)
        guard smtpCandidate.utf8.count <= 254 else {
            return nil
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

        // RFC 5321: host must not be empty
        guard !candidate.isEmpty else { return nil }

        // RFC 1035: total domain must be ≤253 chars
        guard candidate.count <= 253 else { return nil }

        // Split without omitting empty subsequences so that consecutive dots (empty labels),
        // leading dots, and trailing dots are all caught by the per-label checks below.
        let labels = candidate.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.allSatisfy({ label in
            let s = String(label)
            return s.count >= 1          // no empty labels (catches .., leading/trailing dot)
                && s.count <= 63         // RFC 1035: each label ≤63 chars
                && !s.hasPrefix("-")     // RFC 1123: no leading hyphen
                && !s.hasSuffix("-")     // RFC 1123: no trailing hyphen
                && s.unicodeScalars.allSatisfy({ domainLabelCharacterSet.contains($0) })
        }) else {
            return nil
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

    // RFC6531 extends atext to include UTF8-non-ascii (U+0080+)
    // RFC5198 Section 2: Control characters (U+0000-U+001F, U+007F-U+009F) should be avoided
    // We also exclude other problematic characters per security best practices:
    // - Bidirectional formatting characters (U+200E-U+200F, U+202A-U+202E, U+2066-U+2069)
    // - Deprecated format characters (U+206A-U+206F)
    // - Invisible/zero-width characters (U+00AD, U+200B-U+200D, U+2060-U+2064, U+FEFF)
    private static let c1ControlRange: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x80)!...Unicode.Scalar(0x9F)! // C1 control chars
    private static let bidiFormattingChars: CharacterSet = CharacterSet(charactersIn: Unicode.Scalar(0x200E)!...Unicode.Scalar(0x200F)!) // LRM, RLM
        .union(CharacterSet(charactersIn: Unicode.Scalar(0x202A)!...Unicode.Scalar(0x202E)!)) // LRE, RLE, PDF, LRO, RLO
        .union(CharacterSet(charactersIn: Unicode.Scalar(0x2066)!...Unicode.Scalar(0x2069)!)) // LRI, RLI, FSI, PDI
    private static let deprecatedFormatChars: CharacterSet = CharacterSet(charactersIn: Unicode.Scalar(0x206A)!...Unicode.Scalar(0x206F)!) // Deprecated formatting
    private static let bmpPrivateUseChars: CharacterSet = CharacterSet(charactersIn: Unicode.Scalar(0xE000)!...Unicode.Scalar(0xF8FF)!) // BMP Private Use Area
    // Invisible and zero-width format characters that produce no visible glyph.
    // Allowing them enables creating visually-identical but distinct email addresses (spoofing).
    private static let zeroWidthAndInvisibleChars: CharacterSet =
        CharacterSet(charactersIn: Unicode.Scalar(0x00AD)!...Unicode.Scalar(0x00AD)!) // U+00AD Soft Hyphen
        .union(CharacterSet(charactersIn: Unicode.Scalar(0x200B)!...Unicode.Scalar(0x200D)!)) // U+200B ZWS, U+200C ZWNJ, U+200D ZWJ
        .union(CharacterSet(charactersIn: Unicode.Scalar(0x2060)!...Unicode.Scalar(0x2064)!)) // U+2060 Word Joiner, U+2061-U+2064 invisible math operators
        .union(CharacterSet(charactersIn: Unicode.Scalar(0xFEFF)!...Unicode.Scalar(0xFEFF)!)) // U+FEFF BOM / Zero Width No-Break Space
        .union(CharacterSet(charactersIn: Unicode.Scalar(0x2028)!...Unicode.Scalar(0x2029)!)) // U+2028 Line Separator, U+2029 Paragraph Separator

    // Note: CharacterSet.inverted doesn't properly include supplementary planes (U+10000+).
    // Using .inverted on an ASCII-range set also leaks supplementary scalars into the result on
    // some Foundation versions, which then causes the .subtracting() corruption bug (see below).
    // We therefore enumerate non-ASCII BMP explicitly via two contiguous ranges that skip the
    // UTF-16 surrogate block (U+D800-U+DFFF, not valid Swift Unicode.Scalar values).
    // Unicode planes included:
    // - BMP (U+0000-U+FFFF) - non-ASCII portion added via two explicit ranges below
    // - SMP (U+10000-U+1FFFF) - Supplementary Multilingual Plane (emoji, historic scripts)
    // - SIP (U+20000-U+2FFFF) - Supplementary Ideographic Plane (CJK)
    // - TIP (U+30000-U+3FFFF) - Tertiary Ideographic Plane
    // - Planes 4-13 (U+40000-U+DFFFF) - Unassigned
    // - SSP (U+E0000-U+EFFFF) - Supplementary Special-purpose Plane
    //   * Tags block (U+E0000-U+E007F) rejected via explicit scalar guard in parsing functions
    // - PUA (U+F0000-U+10FFFF) - Private Use Areas
    private static let nonAsciiBmpLow: CharacterSet = CharacterSet(charactersIn: Unicode.Scalar(0x0080)!...Unicode.Scalar(0xD7FF)!) // non-ASCII BMP, pre-surrogate
    private static let nonAsciiBmpHigh: CharacterSet = CharacterSet(charactersIn: Unicode.Scalar(0xE000)!...Unicode.Scalar(0xFFFF)!) // non-ASCII BMP, post-surrogate
    private static let supplementaryPlanes: CharacterSet = CharacterSet(charactersIn: Unicode.Scalar(0x10000)!...Unicode.Scalar(0x10FFFF)!)

    // Note: CharacterSet has a bug where .subtracting() corrupts supplementary plane data.
    // Using explicit BMP ranges above (instead of .inverted) ensures no supplementary scalars
    // are present before any .subtracting() call, making the subtractions reliable.
    // supplementaryPlanes must still be added LAST via .union().
    private static let atextUnicodeCharacterSet: CharacterSet = atextCharacterSet
        .union(nonAsciiBmpLow)  // non-ASCII BMP, pre-surrogate
        .union(nonAsciiBmpHigh) // non-ASCII BMP, post-surrogate
        .subtracting(CharacterSet(charactersIn: c1ControlRange)) // Exclude C1 control characters per RFC5198
        .subtracting(bidiFormattingChars) // Exclude bidirectional formatting (security)
        .subtracting(deprecatedFormatChars) // Exclude deprecated format characters
        .subtracting(bmpPrivateUseChars) // Exclude BMP Private Use Area (U+E000-U+F8FF)
        .subtracting(zeroWidthAndInvisibleChars) // Exclude invisible format characters (spoofing prevention)
        .union(supplementaryPlanes) // Supplementary planes (emoji, etc.) - MUST BE LAST (after subtractions)

    // RFC 952/1123: domain labels are LDH (letters, digits, hyphens); Unicode letters are
    // additionally allowed for IDN U-labels per RFC 5891.
    private static let domainLabelCharacterSet: CharacterSet = CharacterSet.letters
        .union(CharacterSet(charactersIn: "0123456789-"))

    private static let quotedPairSMTP: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x20)!...Unicode.Scalar(0x7E)!
    private static let qtextSMTP1: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x20)!...Unicode.Scalar(0x21)!
    private static let qtextSMTP2: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x23)!...Unicode.Scalar(0x5B)!
    private static let qtextSMTP3: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x5D)!...Unicode.Scalar(0x7E)!
    private static let qtextSMTPCharacterSet: CharacterSet = CharacterSet(charactersIn: qtextSMTP1)
        .union(CharacterSet(charactersIn: qtextSMTP2))
        .union(CharacterSet(charactersIn: qtextSMTP3))
    // Same Foundation bug note applies; use explicit BMP ranges and add supplementaryPlanes last.
    private static let qtextUnicodeSMTPCharacterSet = qtextSMTPCharacterSet
        .union(nonAsciiBmpLow)  // non-ASCII BMP, pre-surrogate
        .union(nonAsciiBmpHigh) // non-ASCII BMP, post-surrogate
        .subtracting(CharacterSet(charactersIn: c1ControlRange)) // Exclude C1 control characters per RFC5198
        .subtracting(bidiFormattingChars) // Exclude bidirectional formatting (security)
        .subtracting(deprecatedFormatChars) // Exclude deprecated format characters
        .subtracting(bmpPrivateUseChars) // Exclude BMP Private Use Area (U+E000-U+F8FF)
        .subtracting(zeroWidthAndInvisibleChars) // Exclude invisible format characters (spoofing prevention)
        .union(supplementaryPlanes) // Supplementary planes (emoji, etc.) - MUST BE LAST (after subtractions)

    private static func extractDotAtom(_ candidate: String, compatibility: Compatibility) -> String? {
        guard !candidate.hasPrefix("\""),
              let atRange = candidate.range(of: "@")
        else {
            return nil
        }
        
        let dotAtom = candidate[..<atRange.lowerBound]
        let disallowedCharacterSet: CharacterSet = compatibility == .ascii ? atextCharacterSet.inverted : atextUnicodeCharacterSet.inverted
        guard dotAtom.count > 0,
              dotAtom.utf8.count <= 64,
              !dotAtom.hasPrefix("."),
              !dotAtom.hasSuffix("."),
              dotAtom.components(separatedBy: ".").allSatisfy({ label in
                  label.count > 0
                      && label.rangeOfCharacter(from: disallowedCharacterSet) == nil
                      // Reject Unicode Tags block (U+E0000-U+E007F): deprecated invisible-text
                      // characters included in supplementaryPlanes but unsafe for email.
                      && !label.unicodeScalars.contains(where: { $0.value >= 0xE0000 && $0.value <= 0xE007F })
              })
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
            guard dquotes <= 2 else { return nil }
            guard let characterScalar = character.unicodeScalars.first,
                  character.unicodeScalars.count <= maxScalars
            else {
                return nil
            }
            // Invisible/format scalars can combine with an adjacent base character into a single
            // grapheme cluster. The CharacterSet check below only examines the first scalar, so
            // security-excluded scalars that appear as combining elements would slip through.
            // Scan every scalar in the cluster explicitly to prevent this.
            guard !character.unicodeScalars.contains(where: { s in
                s.value == 0x00AD ||                          // U+00AD Soft Hyphen
                (s.value >= 0x200B && s.value <= 0x200D) ||   // U+200B-U+200D ZWS/ZWNJ/ZWJ
                (s.value >= 0x2060 && s.value <= 0x2064) ||   // U+2060-U+2064 invisible format chars
                s.value == 0xFEFF ||                          // U+FEFF BOM
                (s.value >= 0xE0000 && s.value <= 0xE007F) ||  // U+E0000-U+E007F Unicode Tags block
                (s.value == 0x2028 || s.value == 0x2029)        // U+2028 Line Sep, U+2029 Para Sep
            }) else {
                return nil
            }
            
            if expectingAt {
                guard character == "@",
                      integralText.utf8.count <= 64 else {
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
