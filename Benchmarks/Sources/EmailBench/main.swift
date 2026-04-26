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

if args.contains("--scope") {
    // Per-adapter "within declared scope" report. Drives the second results
    // table in the README — strips test cases whose required capability is
    // outside what the adapter claims, so libraries aren't penalised for
    // standards they never claimed.
    let cases = TestData.allTestCases
    let reports = orderedAdapterKeys.map { runInProcess(key: $0, cases: cases) }
    print("Within-declared-scope accuracy\n")
    print("| Library | Claims | In-scope passed | In-scope failed | Out-of-scope | Skipped | In-scope accuracy |")
    print("|---|---|---:|---:|---:|---:|---:|")
    for r in reports {
        let claims = r.claimedCapabilities.displayList.joined(separator: ", ")
        let pct = r.claimedCapabilities.isEmpty
            ? "n/a"
            : String(format: "%.1f%%", r.inScopeAccuracy * 100)
        print("| \(r.name) | \(claims.isEmpty ? "—" : claims) | \(r.inScopePassed) | \(r.inScopeFailed) | \(r.outOfScope) | \(r.skipped) | \(pct) |")
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
    let claimedCapabilities: Capability
    let passed: Int
    let failed: Int
    let skipped: Int
    let failedCases: [(email: String, expected: Bool, got: Bool, category: TestCategory)]
    // Within-declared-scope counts: a case is in scope iff
    // `requiredCapability(for: c)` is a subset of `claimedCapabilities`.
    let inScopePassed: Int
    let inScopeFailed: Int
    let outOfScope: Int
    var total: Int { passed + failed }
    var accuracy: Double { total > 0 ? Double(passed) / Double(total) : 0 }
    var inScopeTotal: Int { inScopePassed + inScopeFailed }
    var inScopeAccuracy: Double { inScopeTotal > 0 ? Double(inScopePassed) / Double(inScopeTotal) : 0 }
}

func runInProcess(key: String, cases: [EmailTestCase]) -> AdapterReport {
    let adapter = adapterRegistry[key]!
    let skip = SkipList.entries[key] ?? []
    let skipSet = Set(skip.map(\.email))
    let info = staticInfo(for: key)
    var passed = 0, failed = 0, skipped = 0
    var inScopePassed = 0, inScopeFailed = 0, outOfScope = 0
    var failedCases: [(String, Bool, Bool, TestCategory)] = []
    for c in cases {
        if skipSet.contains(c.email) { skipped += 1; continue }
        let got = adapter.validate(c.email)
        let expected = c.expectedResult(for: adapter.referenceMethod)
        let inScope = info.claimedCapabilities.isSuperset(of: requiredCapability(for: c))
        if got == expected {
            passed += 1
            if inScope { inScopePassed += 1 } else { outOfScope += 1 }
        } else {
            failed += 1
            failedCases.append((c.email, expected, got, c.category))
            if inScope { inScopeFailed += 1 } else { outOfScope += 1 }
        }
    }
    return AdapterReport(
        key: key, name: info.name, link: info.link,
        rfcCoverage: info.rfcCoverage, domainValidation: info.domainValidation,
        claimedCapabilities: info.claimedCapabilities,
        passed: passed, failed: failed, skipped: skipped,
        failedCases: failedCases.map { (email: $0.0, expected: $0.1, got: $0.2, category: $0.3) },
        inScopePassed: inScopePassed, inScopeFailed: inScopeFailed, outOfScope: outOfScope
    )
}

struct StaticInfo {
    let name: String
    let link: String
    let rfcCoverage: String
    let domainValidation: Bool
    let claimedCapabilities: Capability
}

func staticInfo(for key: String) -> StaticInfo {
    switch key {
    case "OursAscii":                  return StaticInfo(name: OursAscii.name, link: OursAscii.link, rfcCoverage: OursAscii.rfcCoverage, domainValidation: OursAscii.domainValidation, claimedCapabilities: OursAscii.claimedCapabilities)
    case "OursAsciiUnicode":           return StaticInfo(name: OursAsciiUnicode.name, link: OursAsciiUnicode.link, rfcCoverage: OursAsciiUnicode.rfcCoverage, domainValidation: OursAsciiUnicode.domainValidation, claimedCapabilities: OursAsciiUnicode.claimedCapabilities)
    case "OursUnicode":                return StaticInfo(name: OursUnicode.name, link: OursUnicode.link, rfcCoverage: OursUnicode.rfcCoverage, domainValidation: OursUnicode.domainValidation, claimedCapabilities: OursUnicode.claimedCapabilities)
    case "EvanRobertsonAscii":         return StaticInfo(name: EvanRobertsonAscii.name, link: EvanRobertsonAscii.link, rfcCoverage: EvanRobertsonAscii.rfcCoverage, domainValidation: EvanRobertsonAscii.domainValidation, claimedCapabilities: EvanRobertsonAscii.claimedCapabilities)
    case "EvanRobertsonInternational": return StaticInfo(name: EvanRobertsonInternational.name, link: EvanRobertsonInternational.link, rfcCoverage: EvanRobertsonInternational.rfcCoverage, domainValidation: EvanRobertsonInternational.domainValidation, claimedCapabilities: EvanRobertsonInternational.claimedCapabilities)
    case "MimeParser":                 return StaticInfo(name: MimeParserAdapter.name, link: MimeParserAdapter.link, rfcCoverage: MimeParserAdapter.rfcCoverage, domainValidation: MimeParserAdapter.domainValidation, claimedCapabilities: MimeParserAdapter.claimedCapabilities)
    case "Bdolewski":                  return StaticInfo(name: BdolewskiAdapter.name, link: BdolewskiAdapter.link, rfcCoverage: BdolewskiAdapter.rfcCoverage, domainValidation: BdolewskiAdapter.domainValidation, claimedCapabilities: BdolewskiAdapter.claimedCapabilities)
    case "JweltonEquivalent":          return StaticInfo(name: JweltonEquivalentAdapter.name, link: JweltonEquivalentAdapter.link, rfcCoverage: JweltonEquivalentAdapter.rfcCoverage, domainValidation: JweltonEquivalentAdapter.domainValidation, claimedCapabilities: JweltonEquivalentAdapter.claimedCapabilities)
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

// Capability matrix — what each adapter claims to implement.
print("## Declared capability matrix\n")
print("Each library is graded only against test cases whose required capability is one it claims.")
print("Out-of-scope cases are excluded from the within-declared-scope accuracy below.\n")
let capColumns: [(String, Capability)] = [
    ("RFC 5322",   .rfc5322),
    ("RFC 5321",   .rfc5321IPLit),
    ("RFC 6531",   .rfc6531),
    ("RFC 2047",   .rfc2047),
    ("Domain¹",    .domainPolicy),
    ("Hardening²", .unicodeHard),
]
print("| Library | " + capColumns.map(\.0).joined(separator: " | ") + " |")
print("|---|" + capColumns.map { _ in ":---:" }.joined(separator: "|") + "|")
for r in reports {
    let row = capColumns.map { r.claimedCapabilities.contains($0.1) ? "✅" : "—" }.joined(separator: " | ")
    print("| \(r.name) | \(row) |")
}
print("""

¹ Domain policy = IANA TLD list + RFC 6761 / 6762 / 7686 / 8375 / 9476 special-use blocklist.
² Hardening = UTS #39 / UAX #31 / RFC 6532 §3 — bidi controls, default-ignorable scalars,
  zero-width characters, leading combining marks, tag characters, supplementary-plane attacks.

## Results within declared scope

Test cases whose required capability is outside an adapter's claims are excluded from both
numerator and denominator. This isolates each library's performance against the standards
**it claims to implement** — separate from the headline 243-case score, which grades against
a modern-validator superset.

| Library | In-scope passed | In-scope failed | Out-of-scope | In-scope accuracy |
|---|---:|---:|---:|---:|
""")
for r in reports {
    let pct = r.claimedCapabilities.isEmpty
        ? "n/a³"
        : String(format: "%.1f%%", r.inScopeAccuracy * 100)
    print("| \(r.name) | \(r.inScopePassed) | \(r.inScopeFailed) | \(r.outOfScope) | \(pct) |")
}
let anyEmpty = reports.contains { $0.claimedCapabilities.isEmpty }
if anyEmpty {
    print("\n³ Library declares no specific RFC target, so no test cases are graded as in-scope.")
}
print("")

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
