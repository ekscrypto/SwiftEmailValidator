//
//  UTS39.swift
//  SwiftEmailValidatorUTS39
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Unicode Technical Standard #39 — Unicode Security Mechanisms
//  https://www.unicode.org/reports/tr39/
//

import Foundation

/// Namespace for UTS #39 — Unicode Security Mechanisms — applied on top of
/// RFC-level email validation provided by `SwiftEmailValidator`.
///
/// Use `UTS39.localPartValidator(_:)` and `UTS39.domainValidator(_:)` to build
/// closures that can be passed to `EmailSyntaxValidator.correctlyFormatted` /
/// `mailbox(from:)`. Use the convenience overloads on `EmailSyntaxValidator`
/// (see `UTS39+Convenience.swift`) for the common case.
public enum UTS39 {

    /// UTS #39 §5 Restriction Level ladder.
    ///
    /// Restriction levels are *cumulative*: everything accepted at a tighter
    /// level is accepted at a looser one. ASCII-only is the tightest; it is
    /// not exposed here because the main library already offers `.ascii`
    /// `Compatibility` for that case.
    public enum RestrictionLevel: Equatable {
        /// UTS #39 §5.2.1 — every scalar's Script_Extensions set has a
        /// non-empty intersection with every other scalar's. Common and
        /// Inherited always intersect.
        case singleScript

        /// UTS #39 §5.2.2 — Single Script, or one of the documented
        /// multi-script whitelist combinations:
        /// Latin + Han, Latin + Han + Hiragana + Katakana, Latin + Han + Hangul + Bopomofo.
        /// This is the recommended default for identifier security.
        case highlyRestrictive

        /// UTS #39 §5.2.3 — Highly Restrictive, or Latin plus any single
        /// other Recommended script (excluding Cyrillic and Greek, which
        /// are considered too confusable with Latin to mix freely).
        case moderatelyRestrictive
    }

    /// Configuration for UTS #39 checks.
    ///
    /// `Policy()` applies: `rejectRestrictedIdentifiers = true`, restriction
    /// level = `.highlyRestrictive`, confusables check disabled.
    public struct Policy: Equatable {
        /// Which Restriction Level to enforce for mixed-script detection.
        public var level: RestrictionLevel

        /// Reject scalars whose UTS #39 Identifier_Status is `Restricted`
        /// (obscure and historic scripts such as Linear B, Runic, etc.).
        public var rejectRestrictedIdentifiers: Bool

        /// Reject strings whose UTS #39 §4 skeleton equals the skeleton of
        /// any entry in `confusableSkeletons`. When enabled, callers are
        /// expected to populate `confusableSkeletons` with the expected
        /// forms (brand names, reserved labels, etc.) they want to protect
        /// against. Enabling this without any entries is a no-op.
        public var rejectConfusables: Bool

        /// Strings whose §4 skeleton is treated as protected when
        /// `rejectConfusables` is true. A candidate whose own skeleton
        /// matches one of these is rejected unless it is itself listed in
        /// `confusableAllowlist`.
        public var confusableSkeletons: Set<String>

        /// Exact strings that bypass confusable rejection even if their
        /// skeleton collides with a protected form.
        public var confusableAllowlist: Set<String>

        public init(
            level: RestrictionLevel = .highlyRestrictive,
            rejectRestrictedIdentifiers: Bool = true,
            rejectConfusables: Bool = false,
            confusableSkeletons: Set<String> = [],
            confusableAllowlist: Set<String> = []
        ) {
            self.level = level
            self.rejectRestrictedIdentifiers = rejectRestrictedIdentifiers
            self.rejectConfusables = rejectConfusables
            self.confusableSkeletons = confusableSkeletons
            self.confusableAllowlist = confusableAllowlist
        }
    }
}
