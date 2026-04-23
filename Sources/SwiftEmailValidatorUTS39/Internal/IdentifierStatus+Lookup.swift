//
//  IdentifierStatus+Lookup.swift
//  SwiftEmailValidatorUTS39
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Binary-search helper over the generated `IdentifierStatusData.allowedRanges`.
//

import Foundation

extension IdentifierStatusData {

    /// Is the scalar's UTS #39 Identifier_Status equal to `Allowed`?
    ///
    /// Scalars outside every `Allowed` range have Identifier_Status
    /// `Restricted` (per the UCD `@missing` declaration).
    static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        var lo = 0
        var hi = allowedRanges.count
        while lo < hi {
            let mid = (lo &+ hi) >> 1
            let range = allowedRanges[mid]
            if v < range.lowerBound {
                hi = mid
            } else if v > range.upperBound {
                lo = mid &+ 1
            } else {
                return true
            }
        }
        return false
    }
}
