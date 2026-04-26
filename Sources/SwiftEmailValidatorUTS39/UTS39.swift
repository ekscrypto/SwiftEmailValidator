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
///
/// ## Scope and intentional gaps
///
/// This implementation covers the subset of UTS #39 that maps cleanly onto
/// per-identifier email-component validation: §3 Identifier_Status, §4
/// confusable skeletons, and §5.2 Restriction Levels (Single Script /
/// Highly Restrictive / Moderately Restrictive). The following UTS #39
/// sections are deliberately **not** implemented; callers needing them must
/// layer their own checks over the `localPartValidator` / `domainValidator`
/// hooks:
///
/// - **§5.6.1 Whole-Script Confusables** — character-level skeleton
///   confusion is implemented (see `Policy.rejectConfusables`); the broader
///   whole-script-confusable analysis (e.g. all-Cyrillic strings whose
///   characters individually look like Latin) is out of scope. The Highly
///   Restrictive default already prevents the most common attack — mixing
///   Cyrillic with Latin — by rejecting that combination outright.
/// - **§5.7.1 Mixed-Numbers** — strings combining decimal digits from
///   different numeric systems (e.g. ASCII `4` + Arabic-Indic `٤`) are not
///   detected. The mixed-script check catches this when the digits live in
///   distinct scripts but does not catch Common-script-digit mixing.
/// - **Identifier_Type = Not_NFKC** — inputs are not NFKC-normalized prior
///   to script/identifier checks. The main library deliberately preserves
///   the user-supplied form (RFC 6532 §3.1 says receivers SHOULD NOT apply
///   NFKC); see `EmailNormalizer.nfkc(_:)` if a caller wants opt-in
///   compatibility folding. Any UTS #39 check on the post-NFKC form must be
///   driven explicitly: `UTS39.localPartValidator(...)({ EmailNormalizer.nfkc($0) })`.
///
/// These gaps are documented rather than fixed because each one materially
/// changes user-visible behavior (rejecting historically-accepted inputs);
/// adding them silently inside an addon labeled "UTS #39" would surprise
/// callers who already populated the policy struct.
public enum UTS39 {

    /// UTS #39 §5 Restriction Level ladder.
    ///
    /// Restriction levels are *cumulative*: everything accepted at a tighter
    /// level is accepted at a looser one. ASCII-only is the tightest; it is
    /// not exposed here because the main library already offers `.ascii`
    /// `Compatibility` for that case.
    public enum RestrictionLevel: Equatable {
        /// UTS #39 §5.2 ("Single Script" bullet) — every scalar's UTS #39
        /// §5.1 Augmented_Script_Set has a non-empty intersection with every
        /// other scalar's. The §5.1 closure folds Han into {Hanb, Jpan, Kore},
        /// Hira/Kana into Jpan, Hang into Kore, and Bopo into Hanb, so e.g.
        /// pure-Japanese (Han + Hira + Kana) and pure-Korean (Han + Hang)
        /// strings qualify as Single Script. Common and Inherited always
        /// intersect.
        case singleScript

        /// UTS #39 §5.2 ("Highly Restrictive" bullet) — Single Script, or
        /// one of the documented multi-script whitelist combinations
        /// (Table 1):
        /// - Japanese: Latin + Han + Hiragana + Katakana
        /// - Korean:   Latin + Han + Hangul
        /// - Chinese:  Latin + Han + Bopomofo
        ///
        /// This is the recommended default for identifier security.
        case highlyRestrictive

        /// UTS #39 §5.2 ("Moderately Restrictive" bullet) — Highly
        /// Restrictive, or Latin plus any single other Recommended script
        /// (excluding Cyrillic and Greek, which are considered too
        /// confusable with Latin to mix freely).
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
