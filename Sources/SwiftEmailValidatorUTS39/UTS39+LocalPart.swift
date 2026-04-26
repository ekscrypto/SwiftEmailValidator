//
//  UTS39+LocalPart.swift
//  SwiftEmailValidatorUTS39
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//

import Foundation
import SwiftEmailValidator

public extension UTS39 {

    /// Build a `localPartValidator` closure for
    /// `EmailSyntaxValidator.correctlyFormatted` / `mailbox(from:)`.
    ///
    /// The closure applies the given `Policy` to the semantic local-part
    /// string (dot-atom as-is, or cleaned/unescaped quoted-string).
    ///
    /// An empty string passes (defensive — the RFC layer has already rejected
    /// empty local parts before this closure is invoked).
    static func localPartValidator(_ policy: Policy = .init()) -> (String) -> Bool {
        return { value in
            UTS39.evaluate(value, policy: policy)
        }
    }

    /// Build a `domainValidator` closure for `EmailSyntaxValidator`.
    ///
    /// The returned closure splits the domain on `.` and runs the policy
    /// against each label independently — per UTS #39 §5.1, each IDN label is
    /// its own identifier. It then delegates to `base` (default:
    /// ``TLDDomainValidator/isPubliclyDeliverable(_:)`` — IANA TLD list +
    /// special-use blocklist) for registrability.
    static func domainValidator(
        _ policy: Policy = .init(),
        base: @escaping (String) -> Bool = { TLDDomainValidator.isPubliclyDeliverable($0) }
    ) -> (String) -> Bool {
        return { candidate in
            // Each DNS label is checked in its user-facing (possibly Unicode)
            // form. Punycode ACE labels (`xn--…`) are ASCII and always pass
            // UTS #39 (single-script Latin / Common).
            let labels = candidate.split(separator: ".", omittingEmptySubsequences: false)
            for label in labels where !label.isEmpty {
                if !UTS39.evaluate(String(label), policy: policy) {
                    return false
                }
            }
            return base(candidate)
        }
    }

    /// Run the full policy against a single identifier string. Used by both
    /// `localPartValidator` and `domainValidator`.
    internal static func evaluate(_ value: String, policy: Policy) -> Bool {
        if value.isEmpty { return true }

        if policy.rejectRestrictedIdentifiers {
            for scalar in value.unicodeScalars {
                if !IdentifierStatusData.isAllowed(scalar) {
                    return false
                }
            }
        }

        if !ScriptAnalyzer.passes(value, level: policy.level) {
            return false
        }

        if policy.rejectConfusables, !policy.confusableSkeletons.isEmpty {
            if policy.confusableAllowlist.contains(value) {
                // Explicit allowlist bypasses the confusable check.
            } else {
                let candidateSkeleton = ConfusableSkeleton.skeleton(of: value)
                for protectedForm in policy.confusableSkeletons {
                    if ConfusableSkeleton.skeleton(of: protectedForm) == candidateSkeleton {
                        if protectedForm != value {
                            return false
                        }
                    }
                }
            }
        }

        return true
    }
}
