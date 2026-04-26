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
//  Bidi (RFC 5893) and CONTEXTJ (RFC 5892 §A.1/A.2) checks are out of
//  scope for this initial implementation; see `IDNA.swift` for the
//  documented gaps.
//

import Foundation

enum IdnaProcessing {

    /// Apply UTS #46 §4 step 1 mapping to `input`.
    ///
    /// Returns the mapped string, or `nil` if any scalar maps to `.disallowed`
    /// (or a deviation under transitional mode that is itself disallowed —
    /// not currently produced by the table).
    static func applyMapping(
        _ input: String,
        useSTD3ASCIIRules: Bool,
        transitional: Bool
    ) -> String? {
        var output = String.UnicodeScalarView()
        output.reserveCapacity(input.unicodeScalars.count)

        for scalar in input.unicodeScalars {
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

            // UseSTD3ASCIIRules: in this implementation, the mapping table
            // already classifies non-LDH ASCII (e.g. `_`, `:`, `/`) as
            // `disallowed` for the LDH range, so there's nothing additional
            // to enforce here. The hook is kept as an explicit toggle for
            // future spec changes that may move scalars between buckets.
            _ = useSTD3ASCIIRules
        }
        return String(output)
    }

    /// UTS #46 §4 step 4 label validity check.
    ///
    /// Per the spec, after Punycode decoding `xn--` labels (handled by the
    /// caller), each label must satisfy:
    ///
    ///  - non-empty
    ///  - in NFC
    ///  - if `checkHyphens`: no leading/trailing hyphen; no `--` at positions 3-4
    ///  - does not begin with a combining mark (Mn/Mc/Me)
    ///  - every scalar has status `valid` (or `deviation` in nontransitional)
    ///
    /// Bidi and CONTEXTJ checks are intentionally not run.
    static func validateLabel(
        _ label: String,
        checkHyphens: Bool,
        transitional: Bool
    ) -> Bool {
        if label.isEmpty { return false }

        // NFC check (UTS #46 §4 V1).
        if label.precomposedStringWithCanonicalMapping != label { return false }

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

        // V4/V5: every scalar must be valid (or deviation in nontransitional).
        for s in scalars {
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

        return true
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
        transitional: Bool
    ) -> String? {
        guard let mapped = applyMapping(
            input,
            useSTD3ASCIIRules: useSTD3ASCIIRules,
            transitional: transitional
        ) else { return nil }

        // Step 2: NFC normalize.
        let normalized = mapped.precomposedStringWithCanonicalMapping

        // Step 3: split on U+002E. Preserve empty trailing label so a
        // single trailing dot survives the round-trip.
        let labels = normalized.split(
            separator: ".",
            maxSplits: Int.max,
            omittingEmptySubsequences: false
        ).map(String.init)

        var asciiLabels: [String] = []
        asciiLabels.reserveCapacity(labels.count)

        for (idx, label) in labels.enumerated() {
            // An empty label is only acceptable as the very last entry
            // (representing a trailing root dot); any other empty label
            // signals consecutive dots and must fail.
            if label.isEmpty {
                if idx == labels.count - 1 {
                    asciiLabels.append("")
                    continue
                } else {
                    return nil
                }
            }

            var u = label

            // Step 4 prelude: if label starts with `xn--`, Punycode-decode.
            if u.lowercased().hasPrefix("xn--") {
                let body = String(u.dropFirst(4))
                guard let decoded = Punycode.decode(body) else { return nil }
                u = decoded
                // After decoding, the U-label must again pass validation.
                guard validateLabel(
                    u,
                    checkHyphens: checkHyphens,
                    transitional: transitional
                ) else { return nil }
            } else {
                guard validateLabel(
                    u,
                    checkHyphens: checkHyphens,
                    transitional: transitional
                ) else { return nil }
            }

            // Step 5: encode to ASCII.
            if u.unicodeScalars.allSatisfy({ $0.isASCII }) {
                asciiLabels.append(u)
            } else {
                guard let encoded = Punycode.encode(u) else { return nil }
                let candidate = "xn--" + encoded
                // Length cap (RFC 5890 §2.3.1: ≤ 63 octets per A-label).
                if candidate.utf8.count > 63 { return nil }
                asciiLabels.append(candidate)
            }
        }

        return asciiLabels.joined(separator: ".")
    }
}
