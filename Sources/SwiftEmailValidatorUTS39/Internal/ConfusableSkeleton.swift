//
//  ConfusableSkeleton.swift
//  SwiftEmailValidatorUTS39
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  UTS #39 §4 confusable skeleton computation.
//
//  skeleton(X) = NFD(map(NFD(X)))
//
//  The map step is keyed on NFD forms of the confusables.txt sources (see
//  `ConfusablesData` for the preprocessing rationale). Most mappings are
//  single-scalar and resolved via binary search; a small tail of ~48 entries
//  have multi-scalar NFD expansions and are matched greedily at each
//  position via a short linear table.
//

import Foundation

enum ConfusableSkeleton {

    /// Single-scalar mapping lookup via binary search.
    private static func singleScalarMapping(for scalar: Unicode.Scalar) -> [UInt32]? {
        let v = scalar.value
        var lo = 0
        var hi = ConfusablesData.sources.count
        while lo < hi {
            let mid = (lo &+ hi) >> 1
            let src = ConfusablesData.sources[mid]
            if v < src {
                hi = mid
            } else if v > src {
                lo = mid &+ 1
            } else {
                let start = Int(ConfusablesData.targetOffsets[mid])
                let end = Int(ConfusablesData.targetOffsets[mid &+ 1])
                return Array(ConfusablesData.targetsFlat[start..<end])
            }
        }
        return nil
    }

    /// Longest-match multi-scalar source lookup. Returns the matched source
    /// length and target scalars, or nil if no multi-scalar source matches
    /// at the given starting position.
    ///
    /// `multiScalarSources` is sorted by source length descending, so the
    /// first hit is the longest. Table size is ~48 entries — linear scan is
    /// cheaper than a trie given that cache cost.
    private static func multiScalarMatch(
        in scalars: [Unicode.Scalar],
        startingAt index: Int
    ) -> (length: Int, target: [UInt32])? {
        for tableIndex in 0..<ConfusablesData.multiScalarSources.count {
            let source = ConfusablesData.multiScalarSources[tableIndex]
            if index &+ source.count > scalars.count { continue }
            var match = true
            for offset in 0..<source.count {
                if scalars[index &+ offset].value != source[offset] {
                    match = false
                    break
                }
            }
            if match {
                return (source.count, ConfusablesData.multiScalarTargets[tableIndex])
            }
        }
        return nil
    }

    /// One pass of UTS #39 §4: map each scalar (preferring longest multi-scalar
    /// match) and re-NFD the result.
    private static func mapAndNormalize(_ input: String) -> String {
        let scalars = Array(input.unicodeScalars)
        var out = String.UnicodeScalarView()
        out.reserveCapacity(scalars.count)
        var i = 0
        while i < scalars.count {
            if let match = multiScalarMatch(in: scalars, startingAt: i) {
                for code in match.target {
                    if let s = Unicode.Scalar(code) {
                        out.append(s)
                    }
                }
                i &+= match.length
                continue
            }
            let scalar = scalars[i]
            if let replacement = singleScalarMapping(for: scalar) {
                for code in replacement {
                    if let s = Unicode.Scalar(code) {
                        out.append(s)
                    }
                }
            } else {
                out.append(scalar)
            }
            i &+= 1
        }
        return String(out).decomposedStringWithCanonicalMapping
    }

    /// Compute the UTS #39 §4 confusable skeleton of a string.
    ///
    /// The spec defines skeleton(X) = NFD(map(NFD(X))). In practice, the
    /// confusables.txt table is not transitively closed — a small number of
    /// entries (13 out of ~6500 in Unicode 17.0) map to sequences that
    /// themselves contain further mappable scalars after NFD. We therefore
    /// iterate the map+NFD step to a fixed point (empirical maximum: 3
    /// iterations). This guarantees skeleton idempotence, which callers
    /// expect when diffing candidate strings against protected forms.
    static func skeleton(of string: String) -> String {
        var current = string.decomposedStringWithCanonicalMapping
        for _ in 0..<5 {
            let next = mapAndNormalize(current)
            if next == current { return current }
            current = next
        }
        return current
    }

    /// Are `lhs` and `rhs` §4 confusables?
    static func areConfusable(_ lhs: String, _ rhs: String) -> Bool {
        skeleton(of: lhs) == skeleton(of: rhs)
    }
}
