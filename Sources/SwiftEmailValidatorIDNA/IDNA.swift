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
/// ## Scope and intentional gaps
///
/// This implementation covers the subset of UTS #46 needed to make
/// SwiftEmailValidator's host-validation accept-set match what real DNS
/// resolvers and SMTP clients see post-IDNA. Specifically:
///
///  * §4 step 1 (Map) — full IDNA Mapping Table, current Unicode version.
///  * §4 step 2 (Normalize) — NFC via Foundation.
///  * §4 step 3 (Break into labels) — split on `U+002E`.
///  * §4 step 4 (Validity) — NFC, leading combining mark rejection,
///    `CheckHyphens` (V2), and per-scalar status check (V4/V5).
///  * §4 step 5 (ToASCII) — RFC 3492 Punycode for any non-ASCII U-label,
///    with an RFC 5890 §2.3.1 63-octet cap on the resulting A-label.
///  * `Transitional_Processing` toggle (default off — matches modern
///    browsers and the post-2016 spec recommendation).
///
/// Deliberately **not** implemented in this initial release:
///
///  * **Bidi rule** (RFC 5893 §2). Mixed-direction labels are not detected.
///    Most SMTP/DNS deployments do not enforce Bidi either, so the practical
///    interoperability gap is narrow — but adding this requires bundling
///    Bidi_Class data and is deferred.
///  * **CONTEXTJ / CONTEXTO** rules (RFC 5892 §A.1/A.2). ZWJ/ZWNJ usage in
///    sensitive joining contexts and Greek-keraia / Hebrew-geresh / Hebrew-
///    gershayim / Katakana-middle-dot context rules are not enforced. ZWJ
///    and ZWNJ are still treated as `valid` per the deviation-as-valid rule
///    of nontransitional processing.
///  * **`CheckBidi`** option. Always treated as off.
///
/// Callers needing those checks must layer their own validation on top of
/// ``IDNA/toAscii(_:options:)`` output, or via the `domainValidator`
/// closure chain.
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

        public init(
            transitional: Bool = false,
            checkHyphens: Bool = true,
            useSTD3ASCIIRules: Bool = true
        ) {
            self.transitional = transitional
            self.checkHyphens = checkHyphens
            self.useSTD3ASCIIRules = useSTD3ASCIIRules
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
            transitional: options.transitional)
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
        guard let mapped = IdnaProcessing.applyMapping(
            domain,
            transitional: options.transitional
        ) else { return nil }
        let normalized = mapped.precomposedStringWithCanonicalMapping

        let labels = normalized.split(
            separator: ".",
            maxSplits: Int.max,
            omittingEmptySubsequences: false
        ).map(String.init)

        var out: [String] = []
        out.reserveCapacity(labels.count)
        for (idx, label) in labels.enumerated() {
            if label.isEmpty {
                if idx == labels.count - 1 { out.append(""); continue }
                return nil
            }
            var u = label
            if u.lowercased().hasPrefix("xn--") {
                let body = String(u.dropFirst(4))
                guard let decoded = Punycode.decode(body) else { return nil }
                u = decoded
            }
            guard IdnaProcessing.validateLabel(
                u,
                checkHyphens: options.checkHyphens,
                useSTD3ASCIIRules: options.useSTD3ASCIIRules,
                transitional: options.transitional
            ) else { return nil }
            out.append(u)
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
