//
//  ContextO.swift
//  SwiftEmailValidatorIDNA
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  RFC 5892 §A.3-§A.9 CONTEXTO enforcement. Run as an extra label-validity
//  step on top of UTS #46 §4 when CheckContextO is on. UTS #46 itself does
//  not require CONTEXTO; it is layered here as a security check that
//  prevents homograph confusion between visually similar scripts and
//  digit systems.
//
//  https://datatracker.ietf.org/doc/html/rfc5892#appendix-A.3
//  https://datatracker.ietf.org/doc/html/rfc5892#appendix-A.4
//  https://datatracker.ietf.org/doc/html/rfc5892#appendix-A.5
//  https://datatracker.ietf.org/doc/html/rfc5892#appendix-A.6
//  https://datatracker.ietf.org/doc/html/rfc5892#appendix-A.7
//  https://datatracker.ietf.org/doc/html/rfc5892#appendix-A.8
//  https://datatracker.ietf.org/doc/html/rfc5892#appendix-A.9
//

import Foundation

enum ContextO {

    /// Apply every applicable RFC 5892 §A.3-§A.9 rule to `label`.
    /// Returns `false` on the first violation; `true` when the label
    /// either contains no CONTEXTO scalars or every occurrence is in a
    /// permitted context.
    static func validate(_ label: String) -> Bool {
        let scalars = Array(label.unicodeScalars)
        var sawArabicIndic = false
        var sawExtendedArabicIndic = false

        for (idx, s) in scalars.enumerated() {
            switch s.value {
            case 0x00B7:
                // §A.3 MIDDLE DOT — Before == 'l' AND After == 'l'.
                if !checkMiddleDot(scalars, at: idx) { return false }

            case 0x0375:
                // §A.4 GREEK LOWER NUMERAL SIGN (KERAIA) — next scalar's
                // Script must be Greek.
                if !checkGreekKeraia(scalars, at: idx) { return false }

            case 0x05F3, 0x05F4:
                // §A.5/§A.6 HEBREW PUNCTUATION GERESH/GERSHAYIM —
                // previous scalar's Script must be Hebrew.
                if !checkHebrewPunctuation(scalars, at: idx) { return false }

            case 0x30FB:
                // §A.7 KATAKANA MIDDLE DOT — at least one scalar in the
                // label must have Script ∈ {Hiragana, Katakana, Han}.
                if !checkKatakanaMiddleDot(scalars) { return false }

            case 0x0660...0x0669:
                // §A.8 ARABIC-INDIC DIGITS — label must not contain any
                // Extended Arabic-Indic Digit (U+06F0..U+06F9).
                sawArabicIndic = true

            case 0x06F0...0x06F9:
                // §A.9 EXTENDED ARABIC-INDIC DIGITS — label must not
                // contain any Arabic-Indic Digit (U+0660..U+0669).
                sawExtendedArabicIndic = true

            default:
                continue
            }
        }

        // §A.8 / §A.9 mutual-exclusion check. Either rule alone is fine;
        // the violation is mixing both digit families in the same label.
        if sawArabicIndic && sawExtendedArabicIndic { return false }
        return true
    }

    // MARK: - Per-rule helpers

    /// §A.3 MIDDLE DOT: must be flanked by U+006C ('l') on both sides.
    /// Used to permit the Catalan ela geminada digraph "l·l".
    private static func checkMiddleDot(_ scalars: [Unicode.Scalar], at idx: Int) -> Bool {
        guard idx > 0, idx < scalars.count - 1 else { return false }
        return scalars[idx - 1].value == 0x006C && scalars[idx + 1].value == 0x006C
    }

    /// §A.4 GREEK KERAIA: the *following* scalar must have Script = Greek.
    private static func checkGreekKeraia(_ scalars: [Unicode.Scalar], at idx: Int) -> Bool {
        guard idx + 1 < scalars.count else { return false }
        return ScriptLookup.category(of: scalars[idx + 1].value) == .greek
    }

    /// §A.5 / §A.6 HEBREW GERESH / GERSHAYIM: the *preceding* scalar must
    /// have Script = Hebrew.
    private static func checkHebrewPunctuation(_ scalars: [Unicode.Scalar], at idx: Int) -> Bool {
        guard idx > 0 else { return false }
        return ScriptLookup.category(of: scalars[idx - 1].value) == .hebrew
    }

    /// §A.7 KATAKANA MIDDLE DOT: somewhere in the label, at least one
    /// scalar must have Script ∈ {Hiragana, Katakana, Han}. The middle
    /// dot itself has Script = Common, so it does not satisfy the rule.
    private static func checkKatakanaMiddleDot(_ scalars: [Unicode.Scalar]) -> Bool {
        for s in scalars {
            switch ScriptLookup.category(of: s.value) {
            case .hiragana, .katakana, .han:
                return true
            default:
                continue
            }
        }
        return false
    }
}
