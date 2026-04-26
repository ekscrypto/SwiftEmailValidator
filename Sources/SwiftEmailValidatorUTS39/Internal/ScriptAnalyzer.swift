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

    /// Whitelisted multi-script combinations for the Highly Restrictive level
    /// (UTS #39 §5.2, "Highly Restrictive" bullet).
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

    /// UAX #31 Recommended Scripts (script-typed, i.e. excluding Common /
    /// Inherited / Latin) minus Cyrillic and Greek, which UTS #39 §5.2 calls
    /// out as too confusable with Latin to mix freely under Moderately
    /// Restrictive. This is the candidate "second script" set for the
    /// Latin+other rule. Cherokee is omitted — it is Limited_Use, not
    /// Recommended, so it is intentionally not in the candidate pool.
    ///
    /// Resolved at first use via `ScriptsData.scriptCodes.firstIndex(of:)`
    /// so that re-numbering of script IDs in regenerated data has no effect.
    /// Codes that fail to resolve (i.e. dropped from a future UCD) are
    /// silently skipped rather than producing a sentinel `-1` in the set.
    private static let moderatelyRestrictiveCandidateIDs: Set<Int> = {
        let recommendedSecondScripts = [
            "Arab", "Armn", "Beng", "Bopo", "Deva", "Ethi", "Geor",
            "Gujr", "Guru", "Hang", "Hani", "Hebr", "Hira", "Knda",
            "Kana", "Khmr", "Laoo", "Mlym", "Mymr", "Orya", "Sinh",
            "Taml", "Telu", "Thaa", "Thai", "Tibt",
        ]
        return Set(recommendedSecondScripts.compactMap { ScriptsData.scriptCodes.firstIndex(of: $0) })
    }()

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

    /// Does the string qualify as Single Script per UTS #39 §5.2 ("Single
    /// Script" bullet)?
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
            // Otherwise: Latin + any one Recommended second script.
            // Cyrillic, Greek, and non-Recommended scripts (Phoenician,
            // Limbu, etc.) are excluded by construction of
            // `moderatelyRestrictiveCandidateIDs` — see UTS #39 §5.2,
            // "Moderately Restrictive" bullet.
            let latn = ScriptsData.latnID
            guard latn >= 0 else { return false }
            for scriptID in moderatelyRestrictiveCandidateIDs {
                let target: Set<Int> = [latn, scriptID]
                if stringCompatible(with: target, in: string) {
                    return true
                }
            }
            return false
        }
    }
}
