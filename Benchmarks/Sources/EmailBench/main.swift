import Foundation
import SwiftEmailValidator

// MARK: - Mode parsing

let args = CommandLine.arguments

func argValue(_ flag: String) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

if args.contains("--worker") {
    let key = argValue("--worker") ?? ""
    let start = Int(argValue("--start") ?? "0") ?? 0
    runWorker(adapterKey: key, startIndex: start)
}

if args.contains("--reverse") {
    // Run each harvested competitor test case through our three compatibility
    // modes. A competitor case with `.valid` expectation is counted as passing
    // iff at least one of our modes agrees (since a case like an emoji address
    // is only "valid" in .unicode). `.validOnlyInUnicodeMode` is counted as
    // passing iff .unicode agrees. We use a permissive `domainValidator` so
    // the default IANA TLD + RFC 6761 special-use blocklist doesn't mask
    // pure-syntax disagreements — e.g. evanrobertson's `admin@mailserver1`
    // is a syntax-valid single-label domain that our default rejects as
    // policy, not syntax.

    func ours(_ email: String, mode: EmailSyntaxValidator.Compatibility) -> Bool {
        EmailSyntaxValidator.correctlyFormatted(
            email,
            compatibility: mode,
            allowAddressLiteral: true,
            domainValidator: { _ in true }
        )
    }

    func oursDefault(_ email: String, mode: EmailSyntaxValidator.Compatibility) -> Bool {
        // Default domainValidator = TLDDomainValidator. Shows the shipped
        // behaviour for each competitor test case (relevant when a
        // syntax-level lenient accept is expected to be caught by the
        // default policy layer).
        EmailSyntaxValidator.correctlyFormatted(email, compatibility: mode, allowAddressLiteral: true)
    }

    struct Disagreement {
        let source: String
        let email: String
        let competitorExpected: String
        let ourAscii: Bool
        let ourAsciiUnicode: Bool
        let ourUnicode: Bool
        let defaultValidatorUnicode: Bool
    }

    let cases = ReverseCorpus.all
    var disagreements: [Disagreement] = []
    var passCount = [String: Int]()
    var totalCount = [String: Int]()

    for c in cases {
        totalCount[c.source, default: 0] += 1
        let a = ours(c.email, mode: .ascii)
        let au = ours(c.email, mode: .asciiWithUnicodeExtension)
        let u = ours(c.email, mode: .unicode)
        let agrees: Bool
        switch c.expectation {
        case .valid:
            // Any mode accepting is sufficient agreement.
            agrees = a || au || u
        case .invalid:
            // Every mode must reject to agree.
            agrees = !a && !au && !u
        case .validOnlyInUnicodeMode:
            agrees = u && !a && !au
        }
        if agrees {
            passCount[c.source, default: 0] += 1
        } else {
            let expStr: String = {
                switch c.expectation {
                case .valid: return "valid"
                case .invalid: return "invalid"
                case .validOnlyInUnicodeMode: return "valid (unicode only)"
                }
            }()
            let defaultVerdict = oursDefault(c.email, mode: .unicode)
            disagreements.append(Disagreement(
                source: c.source, email: c.email, competitorExpected: expStr,
                ourAscii: a, ourAsciiUnicode: au, ourUnicode: u,
                defaultValidatorUnicode: defaultVerdict
            ))
        }
    }

    print("# Reverse check — competitor test cases run through SwiftEmailValidator\n")
    print("Using permissive `domainValidator: { _ in true }` so the default IANA TLD")
    print("+ RFC 6761 special-use blocklist (which rejects single-label domains, bare")
    print("TLDs, and reserved names) does not count as a syntax disagreement.")
    print("Input-length caps and character-set rules still apply.\n")
    print("| Source | Total | Agreed | Disagreed |")
    print("|---|---:|---:|---:|")
    let sources = ["evanrobertson", "bdolewski", "jwelton", "igorrendulic"]
    for s in sources {
        let total = totalCount[s] ?? 0
        let passed = passCount[s] ?? 0
        print("| \(s) | \(total) | \(passed) | \(total - passed) |")
    }
    let grandTotal = cases.count
    let grandPassed = passCount.values.reduce(0, +)
    print("| **Total** | \(grandTotal) | \(grandPassed) | \(grandTotal - grandPassed) |")

    if !disagreements.isEmpty {
        print("\n## Disagreements\n")
        print("Rows where our library's verdict differs from the competitor's test assertion.")
        print("`A`=`.ascii`, `A+U`=`.asciiWithUnicodeExtension`, `U`=`.unicode`.\n")
        print("| Source | Input | Competitor | Ours syntax (A / A+U / U) | Default validator (U) |")
        print("|---|---|---|---|---|")
        for d in disagreements {
            let display = d.email.unicodeScalars.map { s -> String in
                (s.value < 0x20 || (s.value >= 0x7F && s.value <= 0x9F))
                    ? String(format: "\\u{%04X}", s.value) : String(s)
            }.joined()
            let ours = "\(d.ourAscii) / \(d.ourAsciiUnicode) / \(d.ourUnicode)"
            print("| \(d.source) | `\(display)` | \(d.competitorExpected) | \(ours) | \(d.defaultValidatorUnicode) |")
        }
        print("\n`Default validator (U)` column shows the shipped behaviour (our `.unicode` mode")
        print("with the default `domainValidator` = `TLDDomainValidator.isPubliclyDeliverable`).")
        print("When it matches the competitor's expectation, the syntax-layer disagreement is")
        print("caught by our default domain-policy layer — so the shipped library agrees with")
        print("the competitor in practice.")
    }
    exit(0)
}

if args.contains("--rfc5322-scope") {
    // A case is "N/A for an RFC 5322-only validator" when:
    //   - its ground truth is `expectedValid == true`, AND
    //   - validating it requires an extension beyond RFC 5322:
    //     either RFC 6531 (non-ASCII code points) or RFC 2047 (encoded-word).
    // Cases that expect rejection remain applicable — a 5322-only validator
    // should still reject them.
    var naByCategory: [TestCategory: Int] = [:]
    var naExamples: [TestCategory: [String]] = [:]
    for c in TestData.allTestCases {
        guard c.expectedValid else { continue }
        let isAscii = c.email.unicodeScalars.allSatisfy { $0.value < 0x80 }
        let isEncodedWord = c.email.hasPrefix("=?") && c.email.hasSuffix("?=")
        if !isAscii || isEncodedWord {
            naByCategory[c.category, default: 0] += 1
            naExamples[c.category, default: []].append(c.email)
        }
    }
    let total = naByCategory.values.reduce(0, +)
    print("RFC 5322-only scope analysis")
    print("Total N/A (valid cases requiring 6531 or 2047): \(total)/\(TestData.allTestCases.count)")
    print("")
    for (cat, count) in naByCategory.sorted(by: { $0.value > $1.value }) {
        print("  \(cat.rawValue): \(count)")
        for ex in (naExamples[cat] ?? []).prefix(3) {
            print("    - \(ex.prefix(60))")
        }
    }
    exit(0)
}

if args.contains("--list") {
    for (idx, c) in TestData.allTestCases.enumerated() {
        // Use %j-ish hex escape for controls so the idx/email stays one line.
        let esc = c.email.unicodeScalars.map { s -> String in
            (s.value < 0x20 || s.value == 0x7F) ? String(format: "\\x%02X", s.value) : String(s)
        }.joined()
        print("\(idx)\t\(esc)")
    }
    exit(0)
}

// MARK: - Default mode: in-process runner with per-adapter skip list

struct AdapterReport {
    let key: String
    let name: String
    let link: String
    let rfcCoverage: String
    let domainValidation: Bool
    let passed: Int
    let failed: Int
    let skipped: Int
    let failedCases: [(email: String, expected: Bool, got: Bool, category: TestCategory)]
    var total: Int { passed + failed }
    var accuracy: Double { total > 0 ? Double(passed) / Double(total) : 0 }
}

func runInProcess(key: String, cases: [EmailTestCase]) -> AdapterReport {
    let adapter = adapterRegistry[key]!
    let skip = SkipList.entries[key] ?? []
    let skipSet = Set(skip.map(\.email))
    var passed = 0, failed = 0, skipped = 0
    var failedCases: [(String, Bool, Bool, TestCategory)] = []
    for c in cases {
        if skipSet.contains(c.email) { skipped += 1; continue }
        let got = adapter.validate(c.email)
        let expected = c.expectedResult(for: adapter.referenceMethod)
        if got == expected { passed += 1 }
        else {
            failed += 1
            failedCases.append((c.email, expected, got, c.category))
        }
    }
    let static_ = staticInfo(for: key)
    return AdapterReport(
        key: key, name: static_.name, link: static_.link,
        rfcCoverage: static_.rfcCoverage, domainValidation: static_.domainValidation,
        passed: passed, failed: failed, skipped: skipped,
        failedCases: failedCases.map { (email: $0.0, expected: $0.1, got: $0.2, category: $0.3) }
    )
}

func staticInfo(for key: String) -> (name: String, link: String, rfcCoverage: String, domainValidation: Bool) {
    switch key {
    case "OursAscii":                  return (OursAscii.name, OursAscii.link, OursAscii.rfcCoverage, OursAscii.domainValidation)
    case "OursAsciiUnicode":           return (OursAsciiUnicode.name, OursAsciiUnicode.link, OursAsciiUnicode.rfcCoverage, OursAsciiUnicode.domainValidation)
    case "OursUnicode":                return (OursUnicode.name, OursUnicode.link, OursUnicode.rfcCoverage, OursUnicode.domainValidation)
    case "EvanRobertsonAscii":         return (EvanRobertsonAscii.name, EvanRobertsonAscii.link, EvanRobertsonAscii.rfcCoverage, EvanRobertsonAscii.domainValidation)
    case "EvanRobertsonInternational": return (EvanRobertsonInternational.name, EvanRobertsonInternational.link, EvanRobertsonInternational.rfcCoverage, EvanRobertsonInternational.domainValidation)
    case "MimeParser":                 return (MimeParserAdapter.name, MimeParserAdapter.link, MimeParserAdapter.rfcCoverage, MimeParserAdapter.domainValidation)
    case "Bdolewski":                  return (BdolewskiAdapter.name, BdolewskiAdapter.link, BdolewskiAdapter.rfcCoverage, BdolewskiAdapter.domainValidation)
    case "JweltonEquivalent":          return (JweltonEquivalentAdapter.name, JweltonEquivalentAdapter.link, JweltonEquivalentAdapter.rfcCoverage, JweltonEquivalentAdapter.domainValidation)
    default: fatalError("unknown adapter key \(key)")
    }
}

func displayEmail(_ s: String) -> String {
    s.unicodeScalars.map { scalar -> String in
        (scalar.value < 0x20 || (scalar.value >= 0x7F && scalar.value <= 0x9F))
            ? String(format: "\\u{%04X}", scalar.value)
            : String(scalar)
    }.joined()
}

let cases = TestData.allTestCases
let reports = orderedAdapterKeys.map { runInProcess(key: $0, cases: cases) }

let verbose = args.contains("--verbose")

print("# Email validator library comparison\n")
print("Corpus: **\(cases.count)** test cases from SwiftEmailValidator's DemoApp (`Benchmarks/Sources/EmailBench/TestData.swift`).\n")
print("| Library | RFC coverage | Domain validation | Passed | Failed | Skipped | Accuracy¹ |")
print("|---|---|---:|---:|---:|---:|---:|")
for r in reports {
    let dv = r.domainValidation ? "✅" : "—"
    let skip = r.skipped == 0 ? "0" : "\(r.skipped)²"
    let pct = String(format: "%.1f%%", r.accuracy * 100)
    print("| [\(r.name)](\(r.link)) | \(r.rfcCoverage) | \(dv) | \(r.passed) | \(r.failed) | \(skip) | \(pct) |")
}

print("""

¹ Accuracy is computed over `Passed + Failed` only; skipped cases are excluded from the denominator.
  Each adapter is compared against the expected outcome that the DemoApp declares for its *reference mode*
  (e.g. `evanrobertson/EmailValidator (international)` is compared against the DemoApp's
  `.swiftEmailUnicode` expectations, because that mode allows non-ASCII local parts).

""")

let totalSkipped = reports.reduce(0) { $0 + $1.skipped }
if totalSkipped > 0 {
    print("² Skipped cases crash the library under test (Swift `fatalError` that cannot be caught in-process).")
    print("  These are hard-coded in `Benchmarks/Sources/EmailBench/SkipList.swift` and counted separately so")
    print("  a single library-level bug doesn't inflate the failure count. See per-library detail below.\n")
    for r in reports where r.skipped > 0 {
        let entries = SkipList.entries[r.key] ?? []
        print("### \(r.name) — \(r.skipped) skipped\n")
        print("| Email | Reason |")
        print("|---|---|")
        for e in entries {
            print("| `\(displayEmail(e.email))` | \(e.reason) |")
        }
        print("")
    }
}

if verbose {
    for r in reports where r.failed > 0 {
        print("\n### \(r.name) — \(r.failed) failing cases\n")
        print("| Email | Category | Expected | Got |")
        print("|---|---|---|---|")
        for f in r.failedCases {
            print("| `\(displayEmail(f.email))` | \(f.category.rawValue) | \(f.expected) | \(f.got) |")
        }
    }
}
