//
//  BidiClass+Lookup.swift
//  SwiftEmailValidatorIDNA
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Binary-search wrapper over the generated BidiClassData table.
//

import Foundation

enum BidiClassLookup {

    /// Look up `scalar` in the Bidi_Class range table. Falls back to
    /// `.other` for any code point not covered (defensive — the generated
    /// table covers the full code point space via UCD `@missing` lines).
    static func category(of scalar: UInt32) -> BidiCategory {
        var lo = 0
        var hi = BidiClassData.rangeCount - 1
        while lo <= hi {
            let mid = (lo + hi) >> 1
            if scalar < BidiClassData.rangeStart[mid] {
                hi = mid - 1
            } else if scalar > BidiClassData.rangeEnd[mid] {
                lo = mid + 1
            } else {
                return BidiCategory(rawValue: BidiClassData.rangeCategory[mid]) ?? .other
            }
        }
        return .other
    }
}
