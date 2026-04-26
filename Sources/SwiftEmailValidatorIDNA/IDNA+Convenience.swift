//
//  IDNA+Convenience.swift
//  SwiftEmailValidatorIDNA
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Convenience overloads on EmailSyntaxValidator that wire UTS #46 IDNA
//  processing into the domain validator in one call.
//

import Foundation
import SwiftEmailValidator

public extension EmailSyntaxValidator {

    /// Validate `candidate` under both RFC-level email syntax rules and
    /// UTS #46 IDNA Compatibility Processing on the host.
    ///
    /// The host is run through ``IDNA/toAscii(_:options:)`` and the
    /// resulting A-label form is then checked against `domainValidator`
    /// (default: ``TLDDomainValidator/_isPubliclyDeliverable(_:)``).
    ///
    /// - Parameters:
    ///   - candidate: String to validate.
    ///   - idna: UTS #46 options (defaults: nontransitional, CheckHyphens on).
    ///   - options: Same semantics as the base `correctlyFormatted`.
    ///   - compatibility: Same semantics as the base `correctlyFormatted`.
    ///   - allowAddressLiteral: Same semantics as the base `correctlyFormatted`.
    ///   - domainValidator: Base domain acceptance check applied to the
    ///     IDNA-normalized ASCII host. Defaults to ``TLDDomainValidator``.
    ///   - localPartValidator: Same semantics as the base `correctlyFormatted`.
    /// - Returns: True if the address passes RFC syntax, IDNA processing,
    ///   and the base domain check.
    static func correctlyFormatted(
        _ candidate: String,
        idna: IDNA.Options,
        options: [Options] = [],
        compatibility: Compatibility = .unicode,
        allowAddressLiteral: Bool = false,
        domainValidator: @escaping (String) -> Bool = { TLDDomainValidator._isPubliclyDeliverable($0) },
        localPartValidator: @escaping (String) -> Bool = { _ in true }
    ) -> Bool {
        return correctlyFormatted(
            candidate,
            options: options,
            compatibility: compatibility,
            allowAddressLiteral: allowAddressLiteral,
            domainValidator: IDNA.domainValidator(idna, base: domainValidator),
            localPartValidator: localPartValidator)
    }

    /// Parse `candidate` into a `Mailbox` under both RFC-level syntax rules
    /// and UTS #46 IDNA processing on the host.
    ///
    /// - Parameters: see ``correctlyFormatted(_:idna:options:compatibility:allowAddressLiteral:domainValidator:localPartValidator:)``.
    /// - Returns: A `Mailbox` on success, or `nil` on either syntactic or
    ///   IDNA failure.
    static func mailbox(
        from candidate: String,
        idna: IDNA.Options,
        options: [Options] = [],
        compatibility: Compatibility = .unicode,
        allowAddressLiteral: Bool = false,
        domainValidator: @escaping (String) -> Bool = { TLDDomainValidator._isPubliclyDeliverable($0) },
        localPartValidator: @escaping (String) -> Bool = { _ in true }
    ) -> Mailbox? {
        return mailbox(
            from: candidate,
            options: options,
            compatibility: compatibility,
            allowAddressLiteral: allowAddressLiteral,
            domainValidator: IDNA.domainValidator(idna, base: domainValidator),
            localPartValidator: localPartValidator)
    }
}
