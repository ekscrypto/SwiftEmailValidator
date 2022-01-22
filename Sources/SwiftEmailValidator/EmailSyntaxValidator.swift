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
        let route: [RoutePoint]

        public enum LocalPart: Equatable {
            case dotAtom(String)
            case quotedString(String)
        }
        
        public enum RoutePoint {
            case domain(String)
            case addressLiteral(String)
        }
    }
    
    public static func match(_ candidate: String, allowHostRoutes: Bool = false, allowAddressLiteral: Bool = false, domainRules: [[String]] = PublicSuffixRulesRegistry.rules) -> Bool {
        mailbox(from: candidate, allowHostRoutes: allowHostRoutes, allowAddressLiteral: allowAddressLiteral, domainRules: domainRules) != nil
    }
    
    public static func mailbox(from candidate: String, allowHostRoutes: Bool = false, allowAddressLiteral: Bool = false, domainRules: [[String]] = PublicSuffixRulesRegistry.rules) -> Mailbox? {
        
        guard let localPart: Mailbox.LocalPart = extractDotAtom(candidate).map({ .dotAtom($0) }) ?? extractQuotedString(candidate).map({ .quotedString($0) })
        else {
            return nil
        }
        
        return Mailbox(
            localPart: localPart,
            route: [])
    }

    private static let digitRange: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x30)!...Unicode.Scalar(0x39)! // 0-9
    private static let alphaUpperRange: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x41)!...Unicode.Scalar(0x5A)! // A-Z
    private static let alphaLowerRange: ClosedRange<Unicode.Scalar> = Unicode.Scalar(0x61)!...Unicode.Scalar(0x7A)! // a-z
    private static let atextCharacterSet = CharacterSet(charactersIn: alphaLowerRange)
        .union(CharacterSet(charactersIn: alphaUpperRange))
        .union(CharacterSet(charactersIn: digitRange))
        .union(CharacterSet(charactersIn: #"!#$%&'*+-/=?^_`{|}~"#)) // Ref RFC5322 section 3.2.3 Atom, definition of atext
    
    private static func extractDotAtom(_ candidate: String) -> String? {
        guard !candidate.hasPrefix("\""),
              let atRange = candidate.range(of: "@")
        else {
            return nil
        }
        
        let dotAtom = candidate[..<atRange.lowerBound]
        guard dotAtom.count > 0,
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
        return nil
    }
}
