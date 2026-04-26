//
//  IdnaMapping+Lookup.swift
//  SwiftEmailValidatorIDNA
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Binary-search wrapper over the generated IdnaMappingData table.
//

import Foundation

/// UTS #46 §5 IDNA Mapping Table status values.
enum IdnaStatus: UInt8 {
    case valid = 0
    case mapped = 1
    case ignored = 2
    case deviation = 3
    case disallowed = 4
}

/// Result of a single-scalar lookup: status plus, where applicable, the
/// scalars to substitute (mapped/deviation cases).
struct IdnaScalarMapping {
    let status: IdnaStatus
    /// Slice of `IdnaMappingData.mappingsFlat` for `mapped` and `deviation`
    /// statuses; empty for `valid`/`ignored`/`disallowed`.
    let mapping: ArraySlice<UInt32>
}

enum IdnaMappingLookup {

    /// Look up `scalar` in the generated mapping table. Falls back to
    /// `.disallowed` if the scalar is outside any range (defensive — the
    /// table covers the entire code-point space in current UCD versions).
    static func lookup(_ scalar: UInt32) -> IdnaScalarMapping {
        var lo = 0
        var hi = IdnaMappingData.rangeCount - 1
        while lo <= hi {
            let mid = (lo + hi) >> 1
            if scalar < IdnaMappingData.rangeStart[mid] {
                hi = mid - 1
            } else if scalar > IdnaMappingData.rangeEnd[mid] {
                lo = mid + 1
            } else {
                guard let status = IdnaStatus(rawValue: IdnaMappingData.rangeStatus[mid]) else {
                    return IdnaScalarMapping(status: .disallowed, mapping: ArraySlice())
                }
                let length = IdnaMappingData.rangeMappingLength[mid]
                if length == 0 {
                    return IdnaScalarMapping(status: status, mapping: ArraySlice())
                }
                let start = Int(IdnaMappingData.rangeMappingOffset[mid])
                let end = start + Int(length)
                return IdnaScalarMapping(
                    status: status,
                    mapping: IdnaMappingData.mappingsFlat[start..<end])
            }
        }
        return IdnaScalarMapping(status: .disallowed, mapping: ArraySlice())
    }
}
