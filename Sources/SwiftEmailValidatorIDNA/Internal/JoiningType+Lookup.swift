//
//  JoiningType+Lookup.swift
//  SwiftEmailValidatorIDNA
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Binary-search wrapper over the generated JoiningTypeData table.
//

import Foundation

enum JoiningTypeLookup {

    /// Look up `scalar` in the Joining_Type range table. Falls back to
    /// `.U` (Non_Joining) for any code point not covered — matches the
    /// UCD default for unlisted scalars.
    static func category(of scalar: UInt32) -> JoiningCategory {
        var lo = 0
        var hi = JoiningTypeData.rangeCount - 1
        while lo <= hi {
            let mid = (lo + hi) >> 1
            if scalar < JoiningTypeData.rangeStart[mid] {
                hi = mid - 1
            } else if scalar > JoiningTypeData.rangeEnd[mid] {
                lo = mid + 1
            } else {
                return JoiningCategory(rawValue: JoiningTypeData.rangeCategory[mid]) ?? .U
            }
        }
        return .U
    }
}

enum ViramaLookup {

    /// Returns true iff `scalar` has Canonical_Combining_Class = 9 (Virama).
    static func isVirama(_ scalar: UInt32) -> Bool {
        var lo = 0
        var hi = ViramaData.count - 1
        while lo <= hi {
            let mid = (lo + hi) >> 1
            let v = ViramaData.scalars[mid]
            if scalar < v {
                hi = mid - 1
            } else if scalar > v {
                lo = mid + 1
            } else {
                return true
            }
        }
        return false
    }
}
