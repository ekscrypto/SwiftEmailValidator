//
//  IdnaTestV2DriverTests.swift
//  SwiftEmailValidatorIDNATests
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Conformance driver against the official Unicode UTS #46 vector set
//  (`IdnaTestV2.txt`, v17.0.0). Each row exercises ToUnicode, ToASCII
//  with `Transitional_Processing=false` (toAsciiN), and ToASCII with
//  `Transitional_Processing=true` (toAsciiT).
//
//  All status code families (`Pn`, `Vn`, `An`, `Bn`, `Cn`, `Xn`, `U1`)
//  are in scope: any row carrying any of them must be rejected by the
//  implementation (`nil` return). `Bn` and `Cn` are specifically the
//  Bidi rule (RFC 5893) and ContextJ (RFC 5892 §A.1/A.2) checks, both
//  enforced by default in this implementation.
//
//  Source file is bundled as a test resource and pinned to the Unicode
//  version embedded in `IdnaMappingData.unicodeVersion`. Refresh both
//  together when rolling Unicode versions.
//

import XCTest
@testable import SwiftEmailValidatorIDNA

final class IdnaTestV2DriverTests: XCTestCase {

    func testIdnaTestV2Conformance() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "IdnaTestV2", withExtension: "txt"),
            "bundled IdnaTestV2.txt resource missing")
        let text = try String(contentsOf: url, encoding: .utf8)

        var rowCount = 0
        var checkCount = 0
        var failures: [String] = []

        var skippedFFFD = 0

        for (lineNo, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            guard let row = Self.parseRow(String(raw)) else { continue }

            // The test file uses U+FFFD as a placeholder for ill-formed
            // input (e.g. unpaired surrogates) in `source` and as a
            // wildcard in expected output. We don't accept ill-formed
            // inputs and don't emit FFFD on errors — skip these rows
            // rather than encode wildcard semantics into the comparator.
            if Self.containsReplacementChar(row) {
                skippedFFFD += 1
                continue
            }

            rowCount += 1

            // CONTEXTO (RFC 5892 §A.3-§A.9) is a non-UTS-#46 extension —
            // UTS #46 vectors are agnostic to it, so disable here to keep
            // the conformance suite measuring strict UTS #46 only. The
            // CONTEXTO rules are exercised independently by ContextOTests.
            let optsN = IDNA.Options(transitional: false, checkContextO: false)
            let optsT = IDNA.Options(transitional: true,  checkContextO: false)
            checkCount += Self.assertOperation(
                op: .toUnicode,
                row: row,
                lineNo: lineNo + 1,
                actual: IDNA.toUnicode(row.source, options: optsN),
                failures: &failures)
            checkCount += Self.assertOperation(
                op: .toAsciiN,
                row: row,
                lineNo: lineNo + 1,
                actual: IDNA.toAscii(row.source, options: optsN),
                failures: &failures)
            checkCount += Self.assertOperation(
                op: .toAsciiT,
                row: row,
                lineNo: lineNo + 1,
                actual: IDNA.toAscii(row.source, options: optsT),
                failures: &failures)
        }

        XCTAssertGreaterThan(rowCount, 1000,
                             "parser yielded only \(rowCount) rows — sanity floor failed")
        // Sanity: a sizeable chunk of vectors exercises ill-formed input
        // (FFFD wildcards). If this number drops to 0, the parser is no
        // longer detecting them and the suite's strictness has silently
        // increased.
        XCTAssertGreaterThan(skippedFFFD, 0,
                             "expected to skip at least some FFFD-containing rows")

        if !failures.isEmpty {
            let preview = failures.prefix(30).joined(separator: "\n")
            XCTFail("""
                IdnaTestV2 conformance: \(failures.count) of \(checkCount) checks across \(rowCount) rows failed.
                First \(min(failures.count, 30)) failures:
                \(preview)
                """)
        }
    }

    // MARK: - Per-operation comparison

    private enum Operation {
        case toUnicode, toAsciiN, toAsciiT

        var label: String {
            switch self {
            case .toUnicode: return "toUnicode"
            case .toAsciiN: return "toAsciiN"
            case .toAsciiT: return "toAsciiT"
            }
        }
    }

    /// Returns the number of checks performed (always 1 — kept for symmetry
    /// with potential future row skips).
    private static func assertOperation(
        op: Operation,
        row: TestRow,
        lineNo: Int,
        actual: String?,
        failures: inout [String]
    ) -> Int {
        let (expected, expectedStatus) = row.expectation(for: op)

        if expectedStatus.isEmpty {
            // Spec says success — implementation must produce `expected`.
            if actual != expected {
                failures.append(
                    "L\(lineNo) \(op.label) source=\(escape(row.source)): "
                    + "expected \(escape(expected)), got \(escape(actual ?? "<nil>"))")
            }
        } else {
            // Spec error path. Implementation must reject (`nil`). A
            // non-nil result here means we silently accepted an input
            // that should fail.
            if actual != nil {
                failures.append(
                    "L\(lineNo) \(op.label) source=\(escape(row.source)) "
                    + "expected error \(expectedStatus) but got \(escape(actual ?? "<nil>"))")
            }
        }
        return 1
    }

    private static func containsReplacementChar(_ row: TestRow) -> Bool {
        let fields = [row.source, row.toUnicode, row.toAsciiN, row.toAsciiT]
        return fields.contains { $0.unicodeScalars.contains(where: { $0.value == 0xFFFD }) }
    }

    private static func escape(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            if scalar.value < 0x20 || scalar.value == 0x7F || scalar.value > 0x7E {
                out += String(format: "\\u%04X", scalar.value)
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
        out += "\""
        return out
    }

    // MARK: - Parsing

    private struct TestRow {
        let source: String
        let toUnicode: String
        let toUnicodeStatus: [String]
        let toAsciiN: String
        let toAsciiNStatus: [String]
        let toAsciiT: String
        let toAsciiTStatus: [String]

        func expectation(for op: Operation) -> (String, [String]) {
            switch op {
            case .toUnicode: return (toUnicode, toUnicodeStatus)
            case .toAsciiN:  return (toAsciiN,  toAsciiNStatus)
            case .toAsciiT:  return (toAsciiT,  toAsciiTStatus)
            }
        }
    }

    /// Parse a single line. Returns `nil` for comments, blank lines, or
    /// malformed rows (any data line in this revision should yield a row).
    private static func parseRow(_ line: String) -> TestRow? {
        // Strip trailing `#`-comment.
        var body = line
        if let hash = body.firstIndex(of: "#") {
            body = String(body[..<hash])
        }
        let trimmed = body.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }

        let rawFields = trimmed.split(separator: ";", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard rawFields.count == 7 else { return nil }

        // Column 1 is always the source (cannot be blank — but `""` represents
        // the literal empty string).
        let source = decodeField(rawFields[0])

        // Resolve blank-inheritance rules per the file header.
        let toUnicode = rawFields[1].isEmpty ? source : decodeField(rawFields[1])
        let toUnicodeStatus = parseStatusSet(rawFields[2].isEmpty ? "[]" : rawFields[2])
        let toAsciiN = rawFields[3].isEmpty ? toUnicode : decodeField(rawFields[3])
        let toAsciiNStatus = rawFields[4].isEmpty ? toUnicodeStatus : parseStatusSet(rawFields[4])
        let toAsciiT = rawFields[5].isEmpty ? toAsciiN : decodeField(rawFields[5])
        let toAsciiTStatus = rawFields[6].isEmpty ? toAsciiNStatus : parseStatusSet(rawFields[6])

        return TestRow(
            source: source,
            toUnicode: toUnicode,
            toUnicodeStatus: toUnicodeStatus,
            toAsciiN: toAsciiN,
            toAsciiNStatus: toAsciiNStatus,
            toAsciiT: toAsciiT,
            toAsciiTStatus: toAsciiTStatus)
    }

    /// Decode `\uXXXX` escapes and treat the literal token `""` as the
    /// empty string. Surrogates passing through unpaired are preserved as
    /// invalid scalar placeholders (`U+FFFD`) — they only appear in test
    /// rows that exercise ill-formed UTF-16 inputs we never accept anyway.
    private static func decodeField(_ field: String) -> String {
        if field == "\"\"" { return "" }
        var out = String.UnicodeScalarView()
        var i = field.startIndex
        while i < field.endIndex {
            let c = field[i]
            if c == "\\",
               field.index(i, offsetBy: 5, limitedBy: field.endIndex) != nil,
               field[field.index(after: i)] == "u"
            {
                let start = field.index(i, offsetBy: 2)
                let end = field.index(start, offsetBy: 4)
                let hex = field[start..<end]
                if let v = UInt32(hex, radix: 16), let s = Unicode.Scalar(v) {
                    out.append(s)
                } else {
                    out.append(Unicode.Scalar(0xFFFD)!)
                }
                i = end
            } else {
                out.append(contentsOf: c.unicodeScalars)
                i = field.index(after: i)
            }
        }
        return String(out)
    }

    /// Parse "[Code1, Code2]" or "[]" into an array of code names.
    private static func parseStatusSet(_ field: String) -> [String] {
        guard field.hasPrefix("["), field.hasSuffix("]") else { return [] }
        let inner = String(field.dropFirst().dropLast())
        if inner.isEmpty { return [] }
        return inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
