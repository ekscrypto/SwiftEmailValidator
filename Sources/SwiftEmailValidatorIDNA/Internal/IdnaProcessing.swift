//
//  IdnaProcessing.swift
//  SwiftEmailValidatorIDNA
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  UTS #46 §4 Processing pipeline:
//    Step 1: Map each scalar via the IDNA Mapping Table.
//    Step 2: Normalize via NFC (RFC 6532 §3.1, also UTS #46 §4 step 2).
//    Step 3: Break into labels on U+002E.
//    Step 4: Validate each label (and Punycode-decode A-labels first).
//    Step 5: ToASCII — Punycode-encode any non-ASCII U-label.
//
//  RFC 5893 Bidi and RFC 5892 §A.1/§A.2 CONTEXTJ run as UTS #46 V6/V7;
//  RFC 5892 §A.3-§A.9 CONTEXTO runs as a non-UTS-#46 security extension
//  layered on top of validateLabel — see IDNA.swift for the policy.
//

import Foundation

enum IdnaProcessing {

    /// Apply UTS #46 §4 step 1 mapping to `input`.
    ///
    /// Returns the mapped string, or `nil` if any scalar maps to `.disallowed`
    /// (or a deviation under transitional mode that is itself disallowed —
    /// not currently produced by the table).
    ///
    /// Note: STD3 enforcement happens in ``validateLabel(_:checkHyphens:useSTD3ASCIIRules:transitional:)``
    /// rather than here, because the modern preprocessed IDNA Mapping Table
    /// classifies non-LDH ASCII (`_`, `/`, `:`, …) as `valid` (with an `NV8`
    /// informational tag); enforcing STD3 requires an explicit per-scalar
    /// check at validation time, applied to post-mapping labels (so e.g.
    /// fullwidth U+FF0F → U+002F is also caught).
    static func applyMapping(
        _ input: String,
        transitional: Bool
    ) -> String? {
        var output = String.UnicodeScalarView()
        output.reserveCapacity(input.unicodeScalars.count)

        for scalar in input.unicodeScalars {
            // UTS #46 §4 step 1 special case: U+1E9E (LATIN CAPITAL LETTER
            // SHARP S) maps to "ss" in Transitional mode; otherwise it
            // follows the table mapping (to U+00DF). The table records the
            // nontransitional mapping, so we override here to keep step 1
            // single-pass and idempotent.
            if transitional && scalar.value == 0x1E9E {
                output.append(Unicode.Scalar(0x73)!)
                output.append(Unicode.Scalar(0x73)!)
                continue
            }

            let entry = IdnaMappingLookup.lookup(scalar.value)
            switch entry.status {
            case .valid:
                output.append(scalar)
            case .ignored:
                continue
            case .disallowed:
                return nil
            case .mapped:
                for v in entry.mapping {
                    guard let s = Unicode.Scalar(v) else { return nil }
                    output.append(s)
                }
            case .deviation:
                if transitional {
                    for v in entry.mapping {
                        guard let s = Unicode.Scalar(v) else { return nil }
                        output.append(s)
                    }
                } else {
                    output.append(scalar)
                }
            }
        }
        return String(output)
    }

    /// UTS #46 §4 step 4 label validity check.
    ///
    /// Per the spec, after Punycode decoding `xn--` labels (handled by the
    /// caller), each label must satisfy:
    ///
    ///  - non-empty
    ///  - in NFC (V1)
    ///  - if `checkHyphens`: no leading/trailing hyphen; no `--` at positions 3-4 (V2)
    ///  - does not begin with a combining mark (Mn/Mc/Me) (V3)
    ///  - every scalar has status `valid` (or `deviation` in nontransitional) (V4/V5)
    ///  - if `useSTD3ASCIIRules`: every ASCII scalar is in the LDH set
    ///    `[A-Za-z0-9-]` (the modern preprocessed IDNA Mapping Table marks
    ///    non-LDH ASCII as `valid` with `NV8`, so the STD3 rule must be
    ///    enforced separately here)
    ///  - if `checkBidi`: RFC 5893 §2 Bidi rule on Bidi domain name labels (V6)
    ///  - if `checkJoiners`: RFC 5892 §A.1 (ZWNJ) and §A.2 (ZWJ) CONTEXTJ (V7)
    ///  - if `checkContextO`: RFC 5892 §A.3-§A.9 CONTEXTO (non-UTS-#46
    ///    security extension; see `IDNA.Options.checkContextO` for details)
    static func validateLabel(
        _ label: String,
        checkHyphens: Bool,
        useSTD3ASCIIRules: Bool,
        transitional: Bool,
        checkBidi: Bool,
        checkJoiners: Bool,
        checkContextO: Bool,
        domainIsBidi: Bool
    ) -> Bool {
        if label.isEmpty { return false }

        // NFC check (UTS #46 §4 V1). Swift String equality is
        // canonical-equivalence-based, so `label != label.precomposed…`
        // would always be false — compare the raw scalar sequences instead.
        if !Array(label.unicodeScalars).elementsEqual(
            label.precomposedStringWithCanonicalMapping.unicodeScalars
        ) {
            return false
        }

        let scalars = Array(label.unicodeScalars)

        // V2: no leading/trailing hyphen, no double-hyphen at 3-4.
        if checkHyphens {
            if scalars.first?.value == 0x2D { return false }
            if scalars.last?.value == 0x2D { return false }
            if scalars.count >= 4
                && scalars[2].value == 0x2D
                && scalars[3].value == 0x2D
            {
                return false
            }
        }

        // V3 in spec V6 (UTS #46 v17): label must not begin with a combining mark.
        if let first = scalars.first {
            let cat = first.properties.generalCategory
            if cat == .nonspacingMark || cat == .spacingMark || cat == .enclosingMark {
                return false
            }
        }

        // V4/V5: every scalar must be valid (or deviation in nontransitional),
        // plus STD3 LDH enforcement on ASCII when requested.
        for s in scalars {
            if useSTD3ASCIIRules && s.value < 0x80 && !isLDH(s.value) {
                return false
            }
            let entry = IdnaMappingLookup.lookup(s.value)
            switch entry.status {
            case .valid:
                continue
            case .deviation:
                if transitional { return false }
            case .mapped, .ignored, .disallowed:
                return false
            }
        }

        // V7: ContextJ — ZWNJ/ZWJ context (RFC 5892 §A.1/A.2). Run before
        // Bidi so that mixed-failure labels report ZWJ/ZWNJ misuse first;
        // ordering doesn't affect correctness since both must pass.
        if checkJoiners && !ContextJ.validate(label) {
            return false
        }

        // V6: Bidi rule (RFC 5893 §2). Per §1.4, the rule fires for every
        // label of a domain in which *any* label contains an R/AL/AN
        // scalar — pure-LTR labels in a Bidi domain are still gated by
        // the rule. The caller computes `domainIsBidi` after splitting.
        if checkBidi && domainIsBidi && !BidiRule.validate(label) {
            return false
        }

        // CONTEXTO (RFC 5892 §A.3-§A.9). Layered on top of UTS #46 §4 —
        // not part of the V1-V7 validity criteria. Run last so the more
        // structural checks (NFC, hyphens, leading combining mark, V4/V5,
        // CONTEXTJ, Bidi) fire first; ordering does not affect correctness
        // since every check must pass.
        if checkContextO && !ContextO.validate(label) {
            return false
        }

        return true
    }

    /// LDH = Letter (A-Z, a-z), Digit (0-9), Hyphen-minus.
    @inline(__always)
    private static func isLDH(_ v: UInt32) -> Bool {
        (v >= 0x61 && v <= 0x7A)        // a-z
            || (v >= 0x30 && v <= 0x39) // 0-9
            || v == 0x2D                // '-'
            || (v >= 0x41 && v <= 0x5A) // A-Z (post-mapping these are gone, but
                                        // validateLabel may be called directly)
    }

    /// UTS #46 §4 step 3: split on U+002E. Operates at the scalar level —
    /// `String.split(separator: ".")` works on grapheme clusters, which
    /// merges `.<ZWJ>` etc. into a single cluster and leaves the dot
    /// embedded inside a label (defeating step 3 entirely).
    static func splitLabels(_ s: String) -> [String] {
        var labels: [String] = []
        var current = String.UnicodeScalarView()
        for scalar in s.unicodeScalars {
            if scalar.value == 0x2E {
                labels.append(String(current))
                current = String.UnicodeScalarView()
            } else {
                current.append(scalar)
            }
        }
        labels.append(String(current))
        return labels
    }

    /// UTS #46 §4 ToASCII implementation.
    ///
    /// Returns the all-ASCII A-label form on success. The result preserves
    /// trailing-dot semantics: a trailing `.` in input remains a trailing
    /// `.` in output. Returns `nil` on any §4 failure.
    static func toAscii(
        _ input: String,
        useSTD3ASCIIRules: Bool,
        checkHyphens: Bool,
        transitional: Bool,
        verifyDnsLength: Bool,
        checkBidi: Bool,
        checkJoiners: Bool,
        checkContextO: Bool
    ) -> String? {
        guard let mapped = applyMapping(
            input,
            transitional: transitional
        ) else { return nil }

        // Step 2: NFC normalize.
        let normalized = mapped.precomposedStringWithCanonicalMapping

        // Step 3: split on U+002E. Preserve empty trailing label so a
        // single trailing dot survives the round-trip when VerifyDnsLength
        // is off.
        let labels = splitLabels(normalized)

        // Pass 1: decode any `xn--` labels to U-label form, handle empty
        // labels, and detect whether any label contains R/AL/AN — the
        // RFC 5893 §1.4 trigger for whole-domain Bidi rule application.
        struct Stage {
            let u: String
            let wasDecoded: Bool
            let isPreservedEmpty: Bool
        }
        var stages: [Stage] = []
        stages.reserveCapacity(labels.count)
        var domainIsBidi = false

        for (idx, label) in labels.enumerated() {
            // Empty-label handling per UTS #46 §4.2 ToASCII step 5:
            //   * VerifyDnsLength=false → an empty trailing label (the DNS
            //     root) is passed through unchanged; intermediate empty
            //     labels (`a..b`) remain a hard error.
            //   * VerifyDnsLength=true  → empty labels are disallowed,
            //     including the trailing root.
            if label.isEmpty {
                if idx == labels.count - 1 && !verifyDnsLength {
                    stages.append(Stage(u: "", wasDecoded: false, isPreservedEmpty: true))
                    continue
                }
                return nil
            }

            var u = label
            var wasDecoded = false

            // Step 4 prelude: if label starts with `xn--`, Punycode-decode.
            // Per UTS #46 §4 step 4, decoded labels are always validated
            // under Nontransitional rules — the spec note explicitly allows
            // already-encoded Punycode containing deviation characters
            // (e.g. `xn--fa-hia.de` for `faß.de`) to round-trip even when
            // Transitional_Processing is requested. The spec also requires
            // rejecting decoded labels that are empty or all-ASCII (P4 in
            // IdnaTestV2 status codes) — a well-behaved encoder never
            // produces those forms.
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

        // Pass 2: validate each U-label with the now-known `domainIsBidi`
        // flag, then encode non-ASCII labels back to A-label form.
        var asciiLabels: [String] = []
        asciiLabels.reserveCapacity(stages.count)
        for stage in stages {
            if stage.isPreservedEmpty {
                asciiLabels.append("")
                continue
            }
            let u = stage.u
            guard validateLabel(
                u,
                checkHyphens: checkHyphens,
                useSTD3ASCIIRules: useSTD3ASCIIRules,
                transitional: stage.wasDecoded ? false : transitional,
                checkBidi: checkBidi,
                checkJoiners: checkJoiners,
                checkContextO: checkContextO,
                domainIsBidi: domainIsBidi
            ) else { return nil }

            // Step 5: encode to ASCII.
            if u.unicodeScalars.allSatisfy({ $0.isASCII }) {
                asciiLabels.append(u)
            } else {
                guard let encoded = Punycode.encode(u) else { return nil }
                asciiLabels.append("xn--" + encoded)
            }
        }

        // Step 5 length checks (UTS #46 §4.2 ToASCII step 5 / RFC 5890
        // §2.3.1). Applied uniformly to every A-label, not just freshly-
        // encoded ones, so a 64-char input ASCII label and an oversized
        // `xn--` input are both caught. Empty trailing labels were already
        // rejected upstream when `verifyDnsLength` is on, so here we know
        // every entry is non-empty.
        if verifyDnsLength {
            for label in asciiLabels {
                let n = label.utf8.count
                if n < 1 || n > 63 { return nil }
            }
            let total = asciiLabels.reduce(0) { $0 + $1.utf8.count }
                + max(0, asciiLabels.count - 1)
            if total < 1 || total > 253 { return nil }
        }

        return asciiLabels.joined(separator: ".")
    }
}
