//
//  IDNA.swift
//  SwiftEmailValidatorIDNA
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Unicode Technical Standard #46 — IDNA Compatibility Processing
//  https://www.unicode.org/reports/tr46/
//

import Foundation
import SwiftEmailValidator

/// Namespace for UTS #46 — Unicode IDNA Compatibility Processing — applied
/// on top of RFC-level email validation provided by `SwiftEmailValidator`.
///
/// Use ``IDNA/domainValidator(_:base:)`` to build a domain-validation closure
/// that runs UTS #46 §4 Processing (Map / Normalize / Validate / ToASCII)
/// over the host before forwarding to a base validator. Use the convenience
/// overloads on `EmailSyntaxValidator` (see `IDNA+Convenience.swift`) for
/// the common case.
///
/// Direct use without the validator integration is supported via
/// ``IDNA/toAscii(_:options:)`` and ``IDNA/toUnicode(_:options:)``.
///
/// ## Scope
///
/// This implementation covers the subset of UTS #46 needed for
/// security-grade host validation. Specifically:
///
///  * §4 step 1 (Map) — full IDNA Mapping Table, current Unicode version.
///  * §4 step 2 (Normalize) — NFC via Foundation.
///  * §4 step 3 (Break into labels) — split on `U+002E`.
///  * §4 step 4 (Validity) — NFC, leading combining mark rejection,
///    `CheckHyphens` (V2), per-scalar status check (V4/V5),
///    `CheckBidi` (V6, RFC 5893 §2), and `CheckJoiners` (V7,
///    RFC 5892 §A.1 ZWNJ + §A.2 ZWJ).
///  * §4 step 5 (ToASCII) — RFC 3492 Punycode for any non-ASCII U-label,
///    with an RFC 5890 §2.3.1 63-octet cap on the resulting A-label.
///  * `Transitional_Processing` toggle (default off — matches modern
///    browsers and the post-2016 spec recommendation).
///
/// In addition, this implementation layers RFC 5892 §A.3-§A.9 CONTEXTO
/// rules on top of UTS #46 as a security-grade extension. CONTEXTO is
/// not part of UTS #46 §4 — it is enabled by default to catch homograph
/// attacks (Greek keraia, Hebrew geresh/gershayim, Catalan middle dot,
/// Katakana middle dot, mixed Arabic-Indic / Extended Arabic-Indic
/// digits) but can be disabled with ``Options/checkContextO``.
public enum IDNA {

    /// Configuration for UTS #46 processing.
    public struct Options: Equatable {

        /// Apply transitional processing (UTS #46 §4: `deviation` characters
        /// — `ß`, `ς`, ZWJ, ZWNJ — are mapped per the IDNA Mapping Table
        /// rather than left as-is).
        ///
        /// Default `false` (nontransitional). This matches the post-2016
        /// spec recommendation and the behavior of all major web browsers.
        public var transitional: Bool

        /// `CheckHyphens` per UTS #46 §4 V2: forbid leading/trailing hyphen
        /// in any label, and forbid `--` at positions 3-4 (the `xn--`
        /// exception is handled before this check fires, since A-label
        /// decoding precedes hyphen validation).
        ///
        /// Default `true`.
        public var checkHyphens: Bool

        /// `UseSTD3ASCIIRules` per UTS #46 §4: when on, every ASCII scalar
        /// in a label must be in the LDH set `[A-Za-z0-9-]`. Non-LDH ASCII
        /// (`_`, `/`, `:`, `@`, `*`, controls, …) is rejected at label
        /// validation, including after fullwidth-to-ASCII mapping (so
        /// `U+FF0F` → `U+002F` is also caught) and after `xn--` decoding.
        ///
        /// The modern preprocessed IDNA Mapping Table marks NV8 scalars as
        /// `valid` rather than `disallowed_STD3_*`, so this enforcement
        /// happens explicitly in our validator rather than via the table
        /// status alone.
        ///
        /// Default `true`.
        public var useSTD3ASCIIRules: Bool

        /// `VerifyDnsLength` per UTS #46 §4.1 ToASCII step 5: each A-label
        /// must be 1-63 octets and the total domain (excluding any trailing
        /// root dot) must be 1-253 octets. Applies to all labels, both
        /// pre-existing ASCII and freshly Punycode-encoded.
        ///
        /// Disable to use ``IDNA/toAscii(_:options:)`` purely as a
        /// mapping/normalization step without DNS-layer length enforcement.
        /// Has no effect on ``IDNA/toUnicode(_:options:)`` — UTS #46 does
        /// not apply DNS length checks during ToUnicode.
        ///
        /// Default `true`.
        public var verifyDnsLength: Bool

        /// `CheckBidi` per UTS #46 §4 V6: enforce the RFC 5893 §2 Bidi
        /// rule on every "Bidi domain name label" (any label containing a
        /// scalar with Bidi_Class R, AL, or AN). Pure-LTR labels are
        /// exempt. Catches mixed-direction labels which are a known
        /// homograph attack vector.
        ///
        /// Default `true`.
        public var checkBidi: Bool

        /// `CheckJoiners` per UTS #46 §4 V7: enforce the RFC 5892 §A.1
        /// (ZWNJ) and §A.2 (ZWJ) CONTEXTJ rules. Catches ZWJ/ZWNJ used
        /// outside their legitimate joining contexts, another homograph
        /// attack vector. Legitimate use in Persian, Indic, etc. scripts
        /// is preserved.
        ///
        /// Default `true`.
        public var checkJoiners: Bool

        /// Enforce the RFC 5892 §A.3-§A.9 CONTEXTO rules on every label.
        /// Specifically:
        ///
        ///  * §A.3 — `U+00B7` (MIDDLE DOT) only between two `'l'` (Catalan
        ///    ela geminada).
        ///  * §A.4 — `U+0375` (GREEK KERAIA) only when followed by a Greek
        ///    scalar.
        ///  * §A.5 / §A.6 — `U+05F3` / `U+05F4` (HEBREW GERESH /
        ///    GERSHAYIM) only when preceded by a Hebrew scalar.
        ///  * §A.7 — `U+30FB` (KATAKANA MIDDLE DOT) only in labels that
        ///    also contain Hiragana, Katakana, or Han.
        ///  * §A.8 / §A.9 — `U+0660..U+0669` (Arabic-Indic Digits) and
        ///    `U+06F0..U+06F9` (Extended Arabic-Indic Digits) must not be
        ///    mixed in the same label.
        ///
        /// CONTEXTO is **not** required by UTS #46 §4 — this is a
        /// security-grade extension layered on top of UTS #46 to catch
        /// homograph attacks across these specific scalar families.
        /// Disable for strict UTS #46 conformance only.
        ///
        /// Default `true`.
        public var checkContextO: Bool

        public init(
            transitional: Bool = false,
            checkHyphens: Bool = true,
            useSTD3ASCIIRules: Bool = true,
            verifyDnsLength: Bool = true,
            checkBidi: Bool = true,
            checkJoiners: Bool = true,
            checkContextO: Bool = true
        ) {
            self.transitional = transitional
            self.checkHyphens = checkHyphens
            self.useSTD3ASCIIRules = useSTD3ASCIIRules
            self.verifyDnsLength = verifyDnsLength
            self.checkBidi = checkBidi
            self.checkJoiners = checkJoiners
            self.checkContextO = checkContextO
        }
    }

    /// Apply UTS #46 §4 Processing followed by ToASCII.
    ///
    /// Returns the all-ASCII (`xn--…` for any non-ASCII labels) form of
    /// `domain` on success, or `nil` if any §4 step rejects the input.
    ///
    /// A single trailing `.` is preserved (an empty final label representing
    /// the DNS root). Empty intermediate labels (`a..b`) are rejected.
    public static func toAscii(
        _ domain: String,
        options: Options = Options()
    ) -> String? {
        IdnaProcessing.toAscii(
            domain,
            useSTD3ASCIIRules: options.useSTD3ASCIIRules,
            checkHyphens: options.checkHyphens,
            transitional: options.transitional,
            verifyDnsLength: options.verifyDnsLength,
            checkBidi: options.checkBidi,
            checkJoiners: options.checkJoiners,
            checkContextO: options.checkContextO)
    }

    /// Apply UTS #46 §4 Processing without forcing ToASCII (UTS #46 ToUnicode).
    ///
    /// The result is the post-mapping, post-NFC, per-label-validated Unicode
    /// form. Any `xn--` labels are decoded to their U-label form. Returns
    /// `nil` on §4 failure.
    public static func toUnicode(
        _ domain: String,
        options: Options = Options()
    ) -> String? {
        // UTS #46 §4 processing on an empty domain produces an empty
        // result; per the conformance vectors that's surfaced as an X4_2
        // error in the toUnicode column, mirroring the behavior of
        // ToASCII under VerifyDnsLength.
        if domain.isEmpty { return nil }

        guard let mapped = IdnaProcessing.applyMapping(
            domain,
            transitional: options.transitional
        ) else { return nil }
        let normalized = mapped.precomposedStringWithCanonicalMapping

        let labels = IdnaProcessing.splitLabels(normalized)

        // Pass 1: decode xn-- labels, handle empty labels, detect whether
        // the domain is a Bidi domain (RFC 5893 §1.4 trigger).
        struct Stage {
            let u: String
            let wasDecoded: Bool
            let isPreservedEmpty: Bool
        }
        var stages: [Stage] = []
        stages.reserveCapacity(labels.count)
        var domainIsBidi = false

        for (idx, label) in labels.enumerated() {
            if label.isEmpty {
                if idx == labels.count - 1 {
                    stages.append(Stage(u: "", wasDecoded: false, isPreservedEmpty: true))
                    continue
                }
                return nil
            }
            var u = label
            // Decoded xn-- labels validate as Nontransitional per UTS #46
            // §4 step 4 — see note in IdnaProcessing.toAscii.
            var wasDecoded = false
            if u.lowercased().hasPrefix("xn--") {
                let body = String(u.dropFirst(4))
                guard let decoded = Punycode.decode(body) else { return nil }
                if decoded.isEmpty { return nil }
                if decoded.unicodeScalars.allSatisfy({ $0.isASCII }) { return nil }
                u = decoded
                wasDecoded = true
            }
            if BidiRule.labelHasRTL(u) { domainIsBidi = true }
            stages.append(Stage(u: u, wasDecoded: wasDecoded, isPreservedEmpty: false))
        }

        // Pass 2: validate each U-label with the now-known `domainIsBidi`.
        var out: [String] = []
        out.reserveCapacity(stages.count)
        for stage in stages {
            if stage.isPreservedEmpty {
                out.append("")
                continue
            }
            guard IdnaProcessing.validateLabel(
                stage.u,
                checkHyphens: options.checkHyphens,
                useSTD3ASCIIRules: options.useSTD3ASCIIRules,
                transitional: stage.wasDecoded ? false : options.transitional,
                checkBidi: options.checkBidi,
                checkJoiners: options.checkJoiners,
                checkContextO: options.checkContextO,
                domainIsBidi: domainIsBidi
            ) else { return nil }
            out.append(stage.u)
        }
        return out.joined(separator: ".")
    }

    /// Build a `domainValidator` closure suitable for
    /// `EmailSyntaxValidator.correctlyFormatted(_:domainValidator:…)` /
    /// `mailbox(from:domainValidator:…)`.
    ///
    /// The returned closure:
    ///   1. Runs ``IDNA/toAscii(_:options:)`` on the host.
    ///   2. On success, forwards the resulting A-label form to `base`
    ///      (default: `TLDDomainValidator._isPubliclyDeliverable`).
    ///   3. Returns `false` if either step fails.
    ///
    /// Pass a custom `base` (e.g. `{ _ in true }`) to use UTS #46 alone.
    public static func domainValidator(
        _ options: Options = Options(),
        base: @escaping (String) -> Bool = { TLDDomainValidator._isPubliclyDeliverable($0) }
    ) -> (String) -> Bool {
        return { domain in
            guard let ascii = toAscii(domain, options: options) else { return false }
            return base(ascii)
        }
    }
}
