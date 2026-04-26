//
//  Script+Lookup.swift
//  SwiftEmailValidatorIDNA
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Binary-search wrapper over the generated ScriptData table.
//

import Foundation

enum ScriptLookup {

    /// Look up `scalar` in the Script range table. Falls back to `.other`
    /// for any scalar that does not belong to one of the five tracked
    /// scripts (Greek, Hebrew, Hiragana, Katakana, Han) — the only ones
    /// referenced by RFC 5892 §A.4-§A.7.
    static func category(of scalar: UInt32) -> ScriptCategory {
        var lo = 0
        var hi = ScriptData.rangeCount - 1
        while lo <= hi {
            let mid = (lo + hi) >> 1
            if scalar < ScriptData.rangeStart[mid] {
                hi = mid - 1
            } else if scalar > ScriptData.rangeEnd[mid] {
                lo = mid + 1
            } else {
                return ScriptCategory(rawValue: ScriptData.rangeCategory[mid]) ?? .other
            }
        }
        return .other
    }
}
