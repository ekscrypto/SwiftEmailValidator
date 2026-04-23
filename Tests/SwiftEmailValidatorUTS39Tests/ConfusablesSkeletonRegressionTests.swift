//
//  ConfusablesSkeletonRegressionTests.swift
//  SwiftEmailValidatorUTS39Tests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Bulk regression coverage: for every (source, target) pair in the generated
//  ConfusablesData, the source scalar and the target scalar-sequence MUST
//  have identical §4 skeletons. This exercises `ConfusableSkeleton.skeleton`
//  across the entire confusables table without pinning any specific
//  per-scalar mapping into the test source.
//
//  The invariant comes from UTS #39 §4: confusables.txt maps each source
//  scalar to its *skeleton* (already NFD-normalized, already irreducible).
//  Therefore skeleton(source) and skeleton(target) must be equal strings.
//

import XCTest
@testable import SwiftEmailValidatorUTS39

final class ConfusablesSkeletonRegressionTests: XCTestCase {

    func testEverySourceSkeletonMatchesItsTargetSkeleton() {
        XCTAssertFalse(ConfusablesData.sources.isEmpty, "data table must not be empty")

        var mismatches: [(source: UInt32, expected: [UInt32], got: String)] = []

        for (index, sourceCodepoint) in ConfusablesData.sources.enumerated() {
            guard let sourceScalar = Unicode.Scalar(sourceCodepoint) else { continue }
            let sourceString = String(sourceScalar)

            let start = Int(ConfusablesData.targetOffsets[index])
            let end = Int(ConfusablesData.targetOffsets[index &+ 1])
            let targetCodepoints = Array(ConfusablesData.targetsFlat[start..<end])

            var targetView = String.UnicodeScalarView()
            targetView.reserveCapacity(targetCodepoints.count)
            for cp in targetCodepoints {
                guard let s = Unicode.Scalar(cp) else {
                    XCTFail("target codepoint U+\(String(cp, radix: 16)) for source U+\(String(sourceCodepoint, radix: 16)) is invalid")
                    continue
                }
                targetView.append(s)
            }
            let targetString = String(targetView)

            let sourceSkeleton = ConfusableSkeleton.skeleton(of: sourceString)
            let targetSkeleton = ConfusableSkeleton.skeleton(of: targetString)

            if sourceSkeleton != targetSkeleton {
                mismatches.append((sourceCodepoint, targetCodepoints, sourceSkeleton))
                if mismatches.count >= 10 {
                    // Cap the report size so failure output stays readable.
                    break
                }
            }
        }

        if !mismatches.isEmpty {
            let details = mismatches.map { entry -> String in
                let hexTarget = entry.expected.map { String(format: "U+%04X", $0) }.joined(separator: " ")
                return "source=U+\(String(format: "%04X", entry.source)) expected-skeleton=[\(hexTarget)] got=\"\(entry.got)\""
            }.joined(separator: "\n  ")
            XCTFail("skeleton mismatches (first \(mismatches.count)):\n  \(details)")
        }
    }

    func testSkeletonIsIdempotent() {
        // For any string X, skeleton(skeleton(X)) == skeleton(X). Spot-check
        // on a representative sample drawn from the data table.
        let sampleIndices = stride(from: 0, to: ConfusablesData.sources.count, by: 173)
        for index in sampleIndices {
            guard let scalar = Unicode.Scalar(ConfusablesData.sources[index]) else { continue }
            let input = String(scalar)
            let once = ConfusableSkeleton.skeleton(of: input)
            let twice = ConfusableSkeleton.skeleton(of: once)
            XCTAssertEqual(once, twice, "skeleton must be idempotent for U+\(String(ConfusablesData.sources[index], radix: 16))")
        }
    }

    func testSkeletonDataTableIsInternallyConsistent() {
        // Sanity: every (source, target offsets) tuple is well-formed.
        XCTAssertEqual(
            ConfusablesData.sources.count,
            ConfusablesData.targetOffsets.count - 1,
            "targetOffsets must have one more entry than sources")
        XCTAssertEqual(
            Int(ConfusablesData.targetOffsets.last ?? 0),
            ConfusablesData.targetsFlat.count,
            "last offset must equal targetsFlat.count")
        // Sources must be strictly increasing (binary search precondition).
        for i in 1..<ConfusablesData.sources.count {
            XCTAssertLessThan(
                ConfusablesData.sources[i - 1],
                ConfusablesData.sources[i],
                "sources must be strictly increasing at index \(i)")
        }
    }
}
