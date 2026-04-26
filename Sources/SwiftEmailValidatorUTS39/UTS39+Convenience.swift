//
//  UTS39+Convenience.swift
//  SwiftEmailValidatorUTS39
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Convenience overloads on EmailSyntaxValidator that wire a UTS #39 policy
//  into both the local-part and domain validators in one call.
//

import Foundation
import SwiftEmailValidator

public extension EmailSyntaxValidator {

    /// Validate `candidate` under both RFC-level email syntax rules and a
    /// UTS #39 security policy.
    ///
    /// The policy is applied to the semantic local-part string and to each
    /// domain label. The domain is also checked against the default
    /// ``TLDDomainValidator/isPubliclyDeliverable(_:)`` (IANA TLD list +
    /// special-use blocklist) unless `domainValidator` is overridden.
    ///
    /// - Parameters:
    ///   - candidate: String to validate.
    ///   - uts39: UTS #39 policy to apply.
    ///   - options: Same semantics as the base `correctlyFormatted`.
    ///   - compatibility: Same semantics as the base `correctlyFormatted`.
    ///   - allowAddressLiteral: Same semantics as the base `correctlyFormatted`.
    ///   - domainValidator: Base domain acceptance check run in addition to
    ///     UTS #39 label analysis. Defaults to ``TLDDomainValidator``.
    ///     Pass `{ _ in true }` to rely on UTS #39 alone.
    /// - Returns: True if the address passes both syntactic and UTS #39 checks.
    static func correctlyFormatted(
        _ candidate: String,
        uts39: UTS39.Policy,
        options: [Options] = [],
        compatibility: Compatibility = .unicode,
        allowAddressLiteral: Bool = false,
        domainValidator: @escaping (String) -> Bool = { TLDDomainValidator._isPubliclyDeliverable($0) }
    ) -> Bool {
        return correctlyFormatted(
            candidate,
            options: options,
            compatibility: compatibility,
            allowAddressLiteral: allowAddressLiteral,
            domainValidator: UTS39.domainValidator(uts39, base: domainValidator),
            localPartValidator: UTS39.localPartValidator(uts39))
    }

    /// Parse `candidate` into a `Mailbox` under both RFC-level email syntax
    /// rules and a UTS #39 security policy.
    ///
    /// - Parameters:
    ///   - candidate: String to validate.
    ///   - uts39: UTS #39 policy to apply.
    ///   - options: Same semantics as the base `mailbox(from:)`.
    ///   - compatibility: Same semantics as the base `mailbox(from:)`.
    ///   - allowAddressLiteral: Same semantics as the base `mailbox(from:)`.
    ///   - domainValidator: Base domain acceptance check run in addition to
    ///     UTS #39 label analysis. Defaults to ``TLDDomainValidator``.
    ///     Pass `{ _ in true }` to rely on UTS #39 alone.
    /// - Returns: A `Mailbox` on success, or `nil` on either syntactic or
    ///   UTS #39 failure.
    static func mailbox(
        from candidate: String,
        uts39: UTS39.Policy,
        options: [Options] = [],
        compatibility: Compatibility = .unicode,
        allowAddressLiteral: Bool = false,
        domainValidator: @escaping (String) -> Bool = { TLDDomainValidator._isPubliclyDeliverable($0) }
    ) -> Mailbox? {
        return mailbox(
            from: candidate,
            options: options,
            compatibility: compatibility,
            allowAddressLiteral: allowAddressLiteral,
            domainValidator: UTS39.domainValidator(uts39, base: domainValidator),
            localPartValidator: UTS39.localPartValidator(uts39))
    }
}
