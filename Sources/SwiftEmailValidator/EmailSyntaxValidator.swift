//
//  EmailSyntaxValidator.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-21.
//  Copyrights (C) 2022, Dave Poirier.  Distributed under MIT license
//
//  References:
//  * RFC5321 https://datatracker.ietf.org/doc/html/rfc5321 Section 4.1.2 & Section 4.1.3

public final class EmailSyntaxValidator {
    
    public struct Mailbox {
        let localPart: LocalPart
        let domain: String?
        let addressLiteral: String?

        public enum LocalPart {
            case dotString(String)
            case quotedString(String)
        }
    }
    
    public static func match(_ candidate: String, allowHostRoutes: Bool = false, allowAddressLiteral: Bool = false, domainRules: [[String]] = PublicSuffixRulesRegistry.rules) -> Bool {
        false
    }
    
    private static func extractDotString(_ candidate: String) -> String? {
        nil
    }
    
    private static func extractQuotedString(_ candidate: String) -> String? {
        nil
    }
}
