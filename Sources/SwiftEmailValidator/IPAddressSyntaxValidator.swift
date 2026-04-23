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

    /// Maximum valid IPv4 address length (e.g. `255.255.255.255` = 15 octets).
    private static let maxIPv4Octets = 15
    /// Maximum valid IPv6 address length, including IPv4-mapped form
    /// (e.g. `ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255` = 45 octets).
    private static let maxIPv6Octets = 45

    // MARK: - Public API
    //
    // The public entry points apply an input-length guard before dispatching to
    // the underlying regex. This prevents a caller from inducing a worst-case
    // regex scan by passing a multi-megabyte string. `EmailSyntaxValidator` uses
    // the unprefixed internal variants directly because it has already enforced
    // an upper bound on the full address.

    /// Validates that the candidate respects either the IPv4 or IPv6 syntax.
    /// - Parameter candidate: String to validate.
    /// - Returns: `true` if the input looks like a valid IPv4 or IPv6 literal.
    public static func match(_ candidate: String) -> Bool {
        guard candidate.utf8.count <= maxIPv6Octets else { return false }
        return _match(candidate)
    }

    /// Validates that the candidate respects the IPv4 syntax.
    /// - Parameter candidate: String to validate.
    /// - Returns: `true` if the input looks like a valid IPv4 address.
    public static func matchIPv4(_ candidate: String) -> Bool {
        guard candidate.utf8.count <= maxIPv4Octets else { return false }
        return _matchIPv4(candidate)
    }

    /// Validates that the candidate respects the IPv6 syntax per RFC 5321.
    /// - Parameter candidate: String to validate.
    /// - Returns: `true` if the input looks like a valid IPv6 address.
    /// - Note: Zone identifiers (e.g. `%eth0`) are not allowed per RFC 5321.
    public static func matchIPv6(_ candidate: String) -> Bool {
        guard candidate.utf8.count <= maxIPv6Octets else { return false }
        return _matchIPv6(candidate)
    }

    // MARK: - Internal API
    //
    // These assume the caller has already bounded the input length. They skip
    // the `utf8.count` guard that the public wrappers enforce. Only call them
    // from inside this module, and only when you have already constrained the
    // input (e.g. `EmailSyntaxValidator` caps the whole address at 254 octets
    // and the host at 253 octets before these are invoked).

    static func _match(_ candidate: String) -> Bool {
        _matchIPv4(candidate) || _matchIPv6(candidate)
    }

    static func _matchIPv4(_ candidate: String) -> Bool {
        let v4regex = #"^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])$"#
        return candidate.range(of: v4regex, options: .regularExpression) != nil
    }

    static func _matchIPv6(_ candidate: String) -> Bool {
        // Based on: https://gist.github.com/syzdek/6086792
        // Modified:
        //   - Removed zone identifier pattern (fe80:...%...) as zone IDs are not valid
        //     in email address literals per RFC 5321 Section 4.1.3
        //   - Added the RFC 4291 §2.2 format 2 alternative: six uncompressed hex groups
        //     followed by an embedded IPv4 suffix (e.g. `aaaa:…:aaaa:127.0.0.1`). The
        //     upstream gist only recognised compressed forms of IPv4-mapped/-embedded
        //     addresses.
        let v6regex = #"^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){6}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$"#
        return candidate.range(of: v6regex, options: .regularExpression) != nil
    }
}
