//
//  IPAddressValidator.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-21.
//  Copyrights (C) 2022, Dave Poirier.  Distributed under MIT license

import Foundation

final public class IPAddressSyntaxValidator {
    
    
    /// Validates that the candidate string either respects the IPv4 or IPv6 syntax
    /// - Parameter candidate: String to validate
    /// - Returns: true if syntax seems  valid, false otherwise
    static func match(_ candidate: String) -> Bool {
        matchIPv4(candidate) || matchIPv6(candidate)
    }
    
    /// Validates that the candidate string respects the IPv4 syntax
    /// - Parameter candidate: String to validate
    /// - Returns: true if syntax eems valid, false otherwise
    static func matchIPv4(_ candidate: String) -> Bool {
        let v4regex = #"^((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])$"#
        return candidate.range(of: v4regex, options: .regularExpression) != nil
    }

    /// Validates that the candidate string respects the IPv6 syntax
    /// - Parameter candidate: String to validate
    /// - Returns: true if syntax eems valid, false otherwise
    static func matchIPv6(_ candidate: String) -> Bool {
        // Source: https://gist.github.com/syzdek/6086792
        let v6regex = #"^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$"#
        return candidate.range(of: v6regex, options: .regularExpression) != nil
    }
}
