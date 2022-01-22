//
//  EmailHostSyntaxValidator.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-21.
//  Copyrights (C) 2022, Dave Poirier.  Distributed under MIT license
//
//  References:
//  Algorithm based on Specifications from https://publicsuffix.org/list/
//  Length & allowed characters validation rules https://www.nic.ad.jp/timeline/en/20th/appendix1.html
//  Further checks added based on https://docs.microsoft.com/en-us/troubleshoot/windows-server/identity/naming-conventions-for-computer-domain-site-ou

import Foundation

final public class EmailHostSyntaxValidator {
    
    public static let publicSuffixDatabase: [[String]] = loadPublicSuffixDatabase()
    public static func isValidEmailHostSyntax(_ candidate: String, rules: [[String]] = publicSuffixDatabase) -> Bool {
        
        guard hostPassesGuards(candidate) else { return false }
        
        let labels = candidate.components(separatedBy: ".")
        guard labels.allSatisfy({ labelPassesGuards($0) }) else { return false }
        
        let matchedSuffixes: [[String]] = rules.filter {
            hostMatchSuffixRules($0, labels: labels)
        }

        if matchedSuffixes.contains(where: { $0.first?.hasPrefix("!") ?? false }) {
            return true
        }
        
        guard let prevailingRule = matchedSuffixes.sorted(by: { $0.count > $1.count }).first else {
            return false
        }
        return labels.count > prevailingRule.count
    }
    
    private static func loadPublicSuffixDatabase() -> [[String]] {
        guard let databaseUrl = Bundle.module.url(forResource: "public_suffix_list", withExtension: "dat"),
              let publicSuffixData = try? Data(contentsOf: databaseUrl),
              let publicSuffixList = String(data: publicSuffixData, encoding: .utf8)?.components(separatedBy: .newlines)
        else {
            return []
        }
        
        return publicSuffixList
            .filter({ !$0.hasPrefix("//") && $0.count > 0 }) // filter out comments and empty lines
            .map({ $0.components(separatedBy: ".") }) // split public suffixes per label
    }
    
    private static func labelPassesGuards(_ label: String) -> Bool {
        (1...63).contains(label.count) && // must contain at least 1 character, no more than 63
        !label.hasPrefix("-") && // must not start with hyphen
        !label.hasSuffix("-") // must not end with hyphen
    }
    
    private static func hostPassesGuards(_ candidate: String) -> Bool {
        let disallowedCharacters = CharacterSet(charactersIn: #",~:!@#$%^&'"(){}_*"#)
            .union(.whitespacesAndNewlines)
            .union(.controlCharacters)
        return (1...253).contains(candidate.count) && // cannot be empty and must be no more than 253 characters long
              candidate.rangeOfCharacter(from: disallowedCharacters) == nil && // must not contain invalid characters
              !candidate.hasPrefix(".") && // cannot start with dot
              !candidate.hasSuffix(".") // cannot end with dot
    }
    
    private static func hostMatchSuffixRules(_ rules: [String], labels: [String]) -> Bool {
        guard rules.count > 0,
              labels.count > 0
        else {
            return false
        }
        
        var rulesToEvaluate = rules
        var labelsLeft = labels
        
        while let rule = rulesToEvaluate.last, let label = labelsLeft.last {
            rulesToEvaluate = rulesToEvaluate.dropLast()
            labelsLeft = labelsLeft.dropLast()
            
            if rule.hasPrefix("!") {
                let exceptionRule = String(rule.dropFirst())
                return exceptionRule == label
            }
            
            if rule == "*" || rule == label { continue }
            return false
        }
        return rulesToEvaluate.count == 0
    }
}
