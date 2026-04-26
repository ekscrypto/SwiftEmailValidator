//
//  BidiRule.swift
//  SwiftEmailValidatorIDNA
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  RFC 5893 §2 — IDNA2008 Right-to-Left Scripts Bidi Rule.
//  https://datatracker.ietf.org/doc/html/rfc5893#section-2
//

import Foundation

enum BidiRule {

    /// Returns true iff any scalar in `label` has Bidi_Class R, AL, or AN.
    /// Used by callers to determine whether a domain is a "Bidi domain
    /// name" per RFC 5893 §1.4 — if any label of the domain returns true,
    /// the rule applies to every label of that domain (including pure-LTR
    /// siblings).
    static func labelHasRTL(_ label: String) -> Bool {
        for s in label.unicodeScalars {
            switch BidiClassLookup.category(of: s.value) {
            case .R, .AL, .AN: return true
            default: continue
            }
        }
        return false
    }

    /// Apply RFC 5893 §2 to `label`. The caller is responsible for the
    /// domain-wide trigger (RFC 5893 §1.4: only invoke when any label of
    /// the domain has an R/AL/AN scalar). Returns `false` to reject.
    static func validate(_ label: String) -> Bool {
        let scalars = Array(label.unicodeScalars)
        if scalars.isEmpty { return true }

        var classes: [BidiCategory] = []
        classes.reserveCapacity(scalars.count)
        for s in scalars {
            classes.append(BidiClassLookup.category(of: s.value))
        }

        // Condition 1: first character must be L, R, or AL.
        let first = classes[0]
        let isRTLLabel: Bool
        switch first {
        case .L:           isRTLLabel = false
        case .R, .AL:      isRTLLabel = true
        default:           return false
        }

        if isRTLLabel {
            // Condition 2: every character must be R, AL, AN, EN, ES, CS,
            // ET, ON, BN, or NSM.
            for c in classes {
                switch c {
                case .R, .AL, .AN, .EN, .ES, .CS, .ET, .ON, .BN, .NSM:
                    continue
                default:
                    return false
                }
            }

            // Condition 3: ending (last char excluding trailing NSMs) must
            // be R, AL, EN, or AN.
            var i = classes.count - 1
            while i > 0 && classes[i] == .NSM { i -= 1 }
            switch classes[i] {
            case .R, .AL, .EN, .AN:
                break
            default:
                return false
            }

            // Condition 4: cannot have both EN and AN in the same label.
            var sawEN = false
            var sawAN = false
            for c in classes {
                if c == .EN { sawEN = true }
                if c == .AN { sawAN = true }
            }
            if sawEN && sawAN { return false }
        } else {
            // LTR label (first char is L) but the label still contains RTL
            // (R/AL/AN) somewhere — since we set hasRTL = true. RFC 5893
            // condition 5: in an LTR label, every character must be L, EN,
            // ES, CS, ET, ON, BN, or NSM. R/AL/AN are not in that list, so
            // any label that is "RTL-mixed" with an L start is rejected.
            for c in classes {
                switch c {
                case .L, .EN, .ES, .CS, .ET, .ON, .BN, .NSM:
                    continue
                default:
                    return false
                }
            }

            // Condition 6: ending (last char excluding trailing NSMs) must
            // be L or EN. (Defensive — given the loop above, only L and EN
            // are reachable here besides ES/CS/ET/ON/BN.)
            var i = classes.count - 1
            while i > 0 && classes[i] == .NSM { i -= 1 }
            switch classes[i] {
            case .L, .EN:
                break
            default:
                return false
            }
        }

        return true
    }
}
