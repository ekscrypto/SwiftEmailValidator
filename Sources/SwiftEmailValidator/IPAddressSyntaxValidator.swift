//
//  IPAddressValidator.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-21.
//  Copyrights (C) 2022, Dave Poirier.  Distributed under MIT license

import Foundation

/// Validates IPv4 and IPv6 address syntax for use in email address literals.
///
/// This validator is used internally by `EmailSyntaxValidator` to validate IP address
/// literals in email hosts when `allowAddressLiteral: true` is specified.
///
/// Per RFC 5321, email addresses can use IP address literals instead of domain names
/// in the format `user@[192.168.1.1]` for IPv4 or `user@[IPv6:2001:db8::1]` for IPv6.
///
/// - Note: Zone identifiers (e.g., `%eth0`) are not allowed per RFC 5321 for email addresses.
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

    /// Validates that the candidate string respects the IPv6 syntax per RFC 5321
    /// - Parameter candidate: String to validate
    /// - Returns: true if syntax seems valid, false otherwise
    /// - Note: Zone identifiers (e.g., %eth0) are NOT allowed per RFC 5321 for email addresses
    static func matchIPv6(_ candidate: String) -> Bool {
        // Based on: https://gist.github.com/syzdek/6086792
        // Modified: Removed zone identifier pattern (fe80:...%...) as zone IDs are not valid
        // in email address literals per RFC 5321 Section 4.1.3
        let v6regex = #"^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$"#
        return candidate.range(of: v6regex, options: .regularExpression) != nil
    }
}
