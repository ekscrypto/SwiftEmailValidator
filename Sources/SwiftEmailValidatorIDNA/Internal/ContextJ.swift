//
//  ContextJ.swift
//  SwiftEmailValidatorIDNA
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  RFC 5892 §A.1 (ZWNJ) and §A.2 (ZWJ) CONTEXTJ enforcement, run as
//  UTS #46 §4 ToASCII validity criterion V7 when CheckJoiners is on.
//  https://datatracker.ietf.org/doc/html/rfc5892#appendix-A.1
//  https://datatracker.ietf.org/doc/html/rfc5892#appendix-A.2
//

import Foundation

enum ContextJ {

    /// ZWNJ rule (RFC 5892 §A.1):
    ///
    ///   If Canonical_Combining_Class(Before(cp)) == Virama → True;
    ///   Else if RegExpMatch((Joining_Type:{L,D})(Joining_Type:T)*\u200C
    ///                       (Joining_Type:T)*(Joining_Type:{R,D})) → True;
    ///   Else False.
    ///
    /// ZWJ rule (RFC 5892 §A.2):
    ///
    ///   If Canonical_Combining_Class(Before(cp)) == Virama → True;
    ///   Else False.
    ///
    /// Applies to every ZWNJ/ZWJ in the label. A single non-conforming
    /// occurrence rejects the whole label.
    static func validate(_ label: String) -> Bool {
        let scalars = Array(label.unicodeScalars)
        for (idx, s) in scalars.enumerated() {
            switch s.value {
            case 0x200C:
                if !checkZWNJ(scalars, at: idx) { return false }
            case 0x200D:
                if !checkZWJ(scalars, at: idx) { return false }
            default:
                continue
            }
        }
        return true
    }

    /// True iff scalar at `idx` (a ZWNJ) satisfies RFC 5892 §A.1.
    private static func checkZWNJ(_ scalars: [Unicode.Scalar], at idx: Int) -> Bool {
        // Rule 1: previous scalar has CCC = Virama.
        if idx > 0, ViramaLookup.isVirama(scalars[idx - 1].value) {
            return true
        }

        // Rule 2: there exists a left-side L|D scalar (preceded only by Ts
        // up to the ZWNJ) AND a right-side R|D scalar (preceded only by Ts
        // from the ZWNJ).
        if idx == 0 || idx == scalars.count - 1 { return false }

        // Walk left over T-class scalars to find the first non-T.
        var i = idx - 1
        while i >= 0 {
            let cat = JoiningTypeLookup.category(of: scalars[i].value)
            if cat == .T { i -= 1; continue }
            // Non-T — must be L or D.
            if cat == .L || cat == .D { break }
            return false
        }
        if i < 0 { return false }

        // Walk right over T-class scalars to find the first non-T.
        var j = idx + 1
        while j < scalars.count {
            let cat = JoiningTypeLookup.category(of: scalars[j].value)
            if cat == .T { j += 1; continue }
            if cat == .R || cat == .D { return true }
            return false
        }
        return false
    }

    /// True iff scalar at `idx` (a ZWJ) satisfies RFC 5892 §A.2.
    private static func checkZWJ(_ scalars: [Unicode.Scalar], at idx: Int) -> Bool {
        guard idx > 0 else { return false }
        return ViramaLookup.isVirama(scalars[idx - 1].value)
    }
}
