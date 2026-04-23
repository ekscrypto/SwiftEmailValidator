//
//  ScriptAnalyzer.swift
//  SwiftEmailValidatorUTS39
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  UTS #39 §5.2 Restriction Level classification and UAX #24
//  Script_Extensions lookup, backed by the generated `ScriptsData`.
//

import Foundation

enum ScriptAnalyzer {

    /// Look up the Script_Extensions set for a scalar. Returns an empty set
    /// for scalars that are not covered by `ScriptsData.ranges` (treated as
    /// Unknown/`Zzzz`, which has no script membership).
    static func scriptExtensions(of scalar: Unicode.Scalar) -> Set<Int> {
        let v = scalar.value
        // Binary search the ranges array.
        var lo = 0
        var hi = ScriptsData.ranges.count
        while lo < hi {
            let mid = (lo &+ hi) >> 1
            let entry = ScriptsData.ranges[mid]
            if v < entry.start {
                hi = mid
            } else if v > entry.end {
                lo = mid &+ 1
            } else {
                return Set(entry.scriptIDs.map { Int($0) })
            }
        }
        return []
    }

    /// Is the scalar a Common (Zyyy) or Inherited (Zinh) scalar?
    ///
    /// Per UTS #39 §5.2, these scripts "act as wildcards" — they intersect
    /// with every script for mixed-script purposes.
    static func isCommonOrInherited(_ scalar: Unicode.Scalar) -> Bool {
        let scripts = scriptExtensions(of: scalar)
        if ScriptsData.commonID >= 0, scripts.contains(ScriptsData.commonID) { return true }
        if ScriptsData.inheritedID >= 0, scripts.contains(ScriptsData.inheritedID) { return true }
        return false
    }

    /// Whitelisted multi-script combinations for UTS #39 §5.2.2
    /// Highly Restrictive level.
    ///
    /// - Japanese: Latin + Han + Hiragana + Katakana
    /// - Korean:   Latin + Han + Hangul
    /// - Chinese:  Latin + Han + Bopomofo
    ///
    /// Latin alone + Han alone are both subsets of every combo and pass
    /// through `isSubset(of:)`.
    private static var highlyRestrictiveCombinations: [Set<Int>] {
        func ids(_ raw: [Int]) -> Set<Int> { Set(raw.filter { $0 >= 0 }) }

        let latn = ScriptsData.latnID
        let hani = ScriptsData.haniID
        let hira = ScriptsData.hiraID
        let kana = ScriptsData.kanaID
        let hang = ScriptsData.hangID
        let bopo = ScriptsData.bopoID

        return [
            ids([latn, hani, hira, kana]),
            ids([latn, hani, hang]),
            ids([latn, hani, bopo]),
        ]
    }

    /// Does every non-wildcard scalar in `string` have a non-empty
    /// intersection with `target`? This is the core "is the string
    /// compatible with this script set?" check: each character must be
    /// assignable to at least one script in `target` (via its
    /// Script_Extensions), with Common/Inherited scalars acting as
    /// universal wildcards.
    private static func stringCompatible(with target: Set<Int>, in string: String) -> Bool {
        for scalar in string.unicodeScalars {
            if isCommonOrInherited(scalar) { continue }
            let scripts = scriptExtensions(of: scalar)
            if scripts.intersection(target).isEmpty {
                return false
            }
        }
        return true
    }

    /// Does the string qualify as Single Script per UTS #39 §5.2.1?
    ///
    /// Single Script: the intersection of Script_Extensions across all
    /// non-Common/non-Inherited scalars is non-empty. A string with no
    /// non-wildcard scalars is vacuously Single Script.
    private static func isSingleScript(_ string: String) -> Bool {
        var intersection: Set<Int>? = nil
        for scalar in string.unicodeScalars {
            if isCommonOrInherited(scalar) { continue }
            let scripts = scriptExtensions(of: scalar)
            if let current = intersection {
                intersection = current.intersection(scripts)
            } else {
                intersection = scripts
            }
        }
        guard let final = intersection else { return true }
        return !final.isEmpty
    }

    /// Evaluate a string against a UTS #39 §5.2 Restriction Level.
    static func passes(_ string: String, level: UTS39.RestrictionLevel) -> Bool {
        if isSingleScript(string) { return true }

        switch level {
        case .singleScript:
            return false

        case .highlyRestrictive:
            // Accept if every non-wildcard scalar's Script_Extensions
            // intersects one of the whitelisted combinations.
            return highlyRestrictiveCombinations.contains(where: { combo in
                stringCompatible(with: combo, in: string)
            })

        case .moderatelyRestrictive:
            // Highly Restrictive satisfies Moderately Restrictive.
            for combo in highlyRestrictiveCombinations {
                if stringCompatible(with: combo, in: string) { return true }
            }
            // Otherwise: Latin + any single other non-excluded script.
            let latn = ScriptsData.latnID
            guard latn >= 0 else { return false }
            let excludedIDs: Set<Int> = {
                var s: Set<Int> = []
                if let cyrl = ScriptsData.scriptCodes.firstIndex(of: "Cyrl") { s.insert(cyrl) }
                if let grek = ScriptsData.scriptCodes.firstIndex(of: "Grek") { s.insert(grek) }
                return s
            }()
            let commonID = ScriptsData.commonID
            let inheritedID = ScriptsData.inheritedID

            for scriptID in 0..<ScriptsData.scriptCodes.count {
                if scriptID == latn { continue }
                if excludedIDs.contains(scriptID) { continue }
                if scriptID == commonID || scriptID == inheritedID { continue }
                let target: Set<Int> = [latn, scriptID]
                if stringCompatible(with: target, in: string) {
                    return true
                }
            }
            return false
        }
    }
}
