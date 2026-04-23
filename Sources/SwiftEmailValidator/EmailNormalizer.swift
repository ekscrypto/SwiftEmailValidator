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
    /// ## Deliberate deviation from RFC 6532 §3.1
    /// RFC 6532 §3.1 recommends NFC (SHOULD) and explicitly says NFKC SHOULD NOT be used,
    /// because compatibility mappings can destroy information needed to spell some names
    /// correctly. This module nevertheless offers NFKC because the target use case is
    /// **anti-spoofing and account de-duplication** — matching the behavior of large mail
    /// providers such as Gmail, where a homograph like `ａｄｍｉｎ` (fullwidth) must collapse
    /// to `admin`. Applications that need **name-preserving** normalization (display,
    /// forwarding, reply-to) should use ``nfc(_:)`` instead, which follows the RFC.
    ///
    /// ## What this function does NOT do
    /// - It does not validate syntax. Input that was not a valid email address remains one;
    ///   input that contains structural garbage remains garbage (normalization does not parse).
    /// - It does not lowercase. RFC 5321 §2.4 declares local parts case-sensitive; lowercasing
    ///   must be an explicit, separate decision (and typically is applied only to the domain).
    /// - It does not distinguish local part from domain. The whole string is normalized as a
    ///   single Unicode stream — the function operates on scalars, not on email structure.
    ///
    /// ## Length is not preserved — always normalize *before* validating
    /// NFKC can substantially expand a string. U+FDFA (ARABIC LIGATURE SALLALLAHOU ALAYHE
    /// WASALLAM) expands to 18 scalars / 33 UTF-8 octets, and its expansion contains ASCII
    /// SPACE characters. A 10-scalar input can therefore exceed the 64-octet local-part limit
    /// (RFC 5321 §4.5.3.1.1) or the 253-octet total mailbox limit (§4.5.3.1.2) after
    /// normalization. Always run validation on the normalized output, never the other way
    /// round; never assume the output fits the same bounds as the input.
    ///
    /// ## Compatibility folds that introduce ASCII SPACE
    /// U+FDFA is the most extreme case but not the only one. Several single-scalar inputs
    /// fold to ASCII SPACE (U+0020) under NFKC and will then be rejected by the validator
    /// because SPACE is not in `atext`:
    /// - `U+00A0` NO-BREAK SPACE → ` `
    /// - `U+2003` EM SPACE, `U+2002` EN SPACE, and most other Zs-category chars → ` `
    /// - `U+FDFA` ARABIC LIGATURE SALLALLAHOU ALAYHE WASALLAM → 18 scalars including ` `
    /// This is a feature, not a bug — homograph spoofing via lookalike spaces collapses to
    /// the canonical SPACE and is then caught by the validator.
    ///
    /// ## Quoted-string local parts
    /// NFKC is applied to the whole string, including content *inside* quoted local parts.
    /// Structurally this is safe: the RFC 5321 delimiters — `"` (U+0022), `\` (U+005C), and
    /// `@` (U+0040) — are ASCII and NFKC is a no-op on ASCII, so the quoting structure is
    /// preserved and `EmailSyntaxValidator.mailbox(from:)` parses the output the same way it
    /// parses the input. Non-ASCII content *between* the quotes is normalized like the rest
    /// of the address (e.g. `"ａｄｍｉｎ"@example.com` → `"admin"@example.com`) — deliberate,
    /// because an attacker who wraps a homograph in quotes would otherwise sidestep the check.
    ///
    /// If your application needs to preserve the exact scalar sequence inside a quoted local
    /// part while still canonicalizing everything else, parse the address first with
    /// `EmailSyntaxValidator.mailbox(from:)` and apply NFKC only to the components you choose
    /// to canonicalize.
    ///
    /// ## RFC 2047 encoded-word input
    /// `=?charset?enc?payload?=` wrappers are pure ASCII, so NFKC is a no-op on them and any
    /// homograph hidden inside the base64/quoted-printable payload survives unchanged. If your
    /// pipeline accepts `.asciiWithUnicodeExtension` input and relies on NFKC for anti-spoofing,
    /// decode the encoded word first and apply NFKC to the decoded UTF-8, not to the wrapper.
    ///
    /// ## IDNA2008 interaction (domain part)
    /// IDNA2008 (RFC 5890–5895) is specified around NFC. NFKC may produce domain-label forms
    /// IDNA2008 treats differently — notably `U+FF0E FULLWIDTH FULL STOP`, `U+3002` IDEOGRAPHIC
    /// FULL STOP, and `U+FF61` HALFWIDTH IDEOGRAPHIC FULL STOP all fold to `.`, creating label
    /// boundaries that did not exist in the input. This mirrors UTS#46 *transitional*-mode
    /// behavior; pure IDNA2008 does not perform that mapping. NFKC may also change a U-label
    /// such that its Punycode encoding (RFC 3492) no longer matches what the caller expected.
    /// Downstream domain validation should be prepared for this; the current
    /// `EmailSyntaxValidator` defers domain validation to a pluggable validator (default:
    /// SwiftPublicSuffixList).
    ///
    /// - Parameter email: An email address string to normalize.
    /// - Returns: The NFKC-normalized form. Pure ASCII input is returned unchanged.
    public static func nfkc(_ email: String) -> String {
        email.precomposedStringWithCompatibilityMapping
    }

    /// Returns the input normalized to Unicode NFC (Normalization Form Canonical Composition).
    ///
    /// NFC collapses only *canonically-equivalent* scalar sequences — primarily combining
    /// character sequences and their precomposed equivalents. It does **not** fold
    /// compatibility variants (fullwidth, ligatures, superscripts, Roman numerals, etc.).
    ///
    /// Examples of what this changes:
    /// - Decomposed `e` + U+0301 COMBINING ACUTE → precomposed `é`
    /// - Decomposed `A` + U+030A COMBINING RING ABOVE → precomposed `Å`
    ///
    /// Examples of what this leaves **untouched** (unlike ``nfkc(_:)``):
    /// - `＠` (U+FF20 FULLWIDTH COMMERCIAL AT) — unchanged
    /// - `ﬁ` (U+FB01 LATIN SMALL LIGATURE FI) — unchanged
    /// - `²` (U+00B2 SUPERSCRIPT TWO) — unchanged
    ///
    /// ## When to use this instead of NFKC
    /// RFC 6532 §3.1 recommends **NFC** (SHOULD) for internationalized local-part comparison,
    /// and specifically says NFKC SHOULD NOT be used because compatibility folding can destroy
    /// information needed to correctly spell names. Use `nfc(_:)` when you need a
    /// spec-compliant comparison form, or when you are normalizing an address you intend to
    /// preserve for display, forwarding, or reply-to. Use ``nfkc(_:)`` when your goal is
    /// anti-spoofing or account de-duplication at the cost of some round-tripping fidelity.
    ///
    /// All the non-normalization caveats from ``nfkc(_:)`` apply here too: no validation,
    /// no case folding, and the whole string is treated as a single Unicode stream.
    ///
    /// - Parameter email: An email address string to normalize.
    /// - Returns: The NFC-normalized form. Pure ASCII input is returned unchanged.
    public static func nfc(_ email: String) -> String {
        email.precomposedStringWithCanonicalMapping
    }
}
