//
//  EmailNormalizer.swift
//  SwiftEmailValidator
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Unicode Standard Annex #15 (Normalization Forms):
//  * NFKC (Normalization Form KC) = Compatibility Decomposition followed by Canonical Composition.
//    See https://unicode.org/reports/tr15/ for the formal definition.
//
//  Intentionally decoupled from EmailSyntaxValidator. This type does not validate, parse, or
//  structurally inspect the input — it only applies NFKC to the string as-is. Callers who want
//  a validated + normalized result should pipe the output of `nfkc(_:)` into
//  `EmailSyntaxValidator.correctlyFormatted(_:)` or `EmailSyntaxValidator.mailbox(from:)`.

import Foundation

/// Unicode-based normalization helpers for email addresses.
///
/// `EmailNormalizer` is deliberately separate from ``EmailSyntaxValidator``. Validation answers
/// "is this syntactically well-formed?"; normalization answers "what is the canonical form of
/// this string?". The two are composable but conceptually distinct, and applications typically
/// want to choose whether to normalize, and how, independently from validation.
///
/// ## Typical pipeline
/// ```swift
/// let normalized = EmailNormalizer.nfkc(userInput)
/// if let mailbox = EmailSyntaxValidator.mailbox(from: normalized) {
///     // Persist / compare / authenticate using the normalized form.
/// }
/// ```
public enum EmailNormalizer {

    /// Returns the input normalized to Unicode NFKC (Normalization Form Compatibility Composition).
    ///
    /// NFKC collapses *compatibility-equivalent* scalars to a single canonical representation.
    /// Examples of what this changes:
    /// - `＠` (U+FF20 FULLWIDTH COMMERCIAL AT) → `@`
    /// - `１２３` (U+FF11–U+FF13 FULLWIDTH DIGITS) → `123`
    /// - `ﬁ` (U+FB01 LATIN SMALL LIGATURE FI) → `fi`
    /// - `²` (U+00B2 SUPERSCRIPT TWO) → `2`
    /// - `ℌ` (U+210C BLACK-LETTER CAPITAL H) → `H`
    /// - Decomposed `e` + U+0301 COMBINING ACUTE → precomposed `é`
    ///
    /// This is the normalization form used by many large mail providers for equality
    /// comparison and account de-duplication, because it maps visually-indistinguishable
    /// inputs to the same byte sequence.
    ///
    /// ## What this function does NOT do
    /// - It does not validate syntax. Input that was not a valid email address remains one;
    ///   input that contains structural garbage remains garbage (normalization does not parse).
    /// - It does not lowercase. RFC 5321 §2.4 declares local parts case-sensitive; lowercasing
    ///   must be an explicit, separate decision (and typically is applied only to the domain).
    /// - It does not distinguish local part from domain. The whole string is normalized as a
    ///   single Unicode stream — which is the correct behavior for NFKC, since the function
    ///   operates on scalars, not on email structure.
    ///
    /// ## Quoted-string local parts
    /// NFKC is applied to the whole string, including content *inside* quoted local parts. This
    /// is safe structurally: the RFC 5321 delimiters — `"` (U+0022), `\` (U+005C), and `@`
    /// (U+0040) — are ASCII and NFKC is a no-op on ASCII, so the quoting structure is preserved
    /// and `EmailSyntaxValidator.mailbox(from:)` parses the output the same way it parses the
    /// input. Non-ASCII content *between* the quotes, however, is normalized like the rest of
    /// the address (e.g. `"ａｄｍｉｎ"@example.com` → `"admin"@example.com`). That is deliberate:
    /// the primary motivation for NFKC here is spoofing / account de-duplication, and an
    /// attacker who wraps a homograph in quotes would otherwise sidestep the check. RFC 6532
    /// §3.1 recommends normalization without distinguishing quoted vs. unquoted local parts.
    ///
    /// If your application genuinely needs to preserve the exact scalar sequence inside a
    /// quoted local part while still canonicalizing everything else, parse the address first
    /// with `EmailSyntaxValidator.mailbox(from:)` and apply NFKC only to the components you
    /// choose to canonicalize.
    ///
    /// - Parameter email: An email address string to normalize.
    /// - Returns: The NFKC-normalized form. Pure ASCII input is returned unchanged.
    public static func nfkc(_ email: String) -> String {
        email.precomposedStringWithCompatibilityMapping
    }
}
