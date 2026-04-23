# SwiftEmailValidator — Current State Review

_Reviewed 2026-04-22._

## Overall

This is a **solid, mature library** in unusually good shape. 125 tests pass in
<0.2s, the security hardening over the last few weeks has been thorough and
well-documented, and the architecture is appropriately small (3 source files,
~780 LOC). It's noticeably above the average open-source Swift package.

## What's good

- **Security focus is real, not theatrical.** Recent commits target genuine
  spoofing vectors (Zs spaces, supplementary noncharacters, Variation
  Selectors, Tags block, bidi, C1 Q-decode). Most validators don't think about
  Unicode §23.7 at all.
- **Test breadth is strong.** Boundary tests (exact 64/254/253 octets),
  byte-vs-char distinction, dual coverage for dot-atom + quoted-string paths,
  spoofing regression cases.
- **Pluggable `domainValidator` closure** is the right API choice.
- **Clear documentation of Foundation bugs** (CharacterSet `.subtracting()`
  corrupting supplementary planes) inline at the workaround.
- **DemoApp comparing 4 validators** is a great differentiator.

## Concrete issues worth fixing

1. **Stale doc comments in `EmailSyntaxValidator.swift:114, 118, 135`** —
   reference `strategy:` / `ValidationStrategy` / `smtpHeader` which don't
   exist. API uses `options:` / `Options`. This is the only outright bug.
2. **`SECURITY.md` lists 1.0.3 as supported** — project is on 1.1.0 with
   significant unreleased security work.
3. **`CHANGELOG.md` ends at 1.1.0 (Dec 2025)** — none of the Apr 2026 security
   sessions are recorded. Users have no way to know what changed.
4. **README install example pins `from: "1.0.2"`** — should be 1.1.x.
5. **CI is on deprecated infra**: `actions/checkout@v2`,
   `codecov-action@v2.1.0`, `upload-sarif@v1`, `ubuntu-20.04` (retired).
   Workflows still run but will break.
6. **No tag/release for the security work.** Anyone consuming via SPM
   `upToNextMajor(from: "1.1.0")` gets the 1.1.0 release, missing every
   security fix since.

## Design observations (smaller)

- **Duplicated security-scalar guard** between `extractDotAtom`
  (`EmailSyntaxValidator.swift:436-442`) and `extractQuotedString`
  (`EmailSyntaxValidator.swift:480-500`). The comment acknowledges this;
  extracting `static func isSecurityRejectedScalar(_:)` would prevent drift.
- **`Options` is a single-case enum used as `[Options]`** — `Bool` or
  `OptionSet` would be more honest about intent.
- **548-line `EmailSyntaxValidator.swift`** is mostly the CharacterSet wall
  (`EmailSyntaxValidator.swift:287-406`). Splitting into a `CharacterSets.swift`
  would improve readability without behavior change.
- **1273-line test file** — splitting by theme (Boundaries / Unicode /
  Spoofing / IPLiteral / Domain) would help navigation.
- **No property-based / fuzz tests.** Given how often Unicode edge cases bite
  this code, randomized scalar generation against invariants ("invalid input
  never crashes, never returns valid for blocked sets") would pay off.

## Bottom line

Code quality and correctness are excellent. The gap is **release hygiene**:
docs, changelog, security policy, CI versions, and tag/version don't reflect
the work that's been done. A 1.1.1 (or 1.2.0) release with an updated
CHANGELOG, fixed doc comments, refreshed SECURITY.md, and bumped Action
versions would close that gap in an afternoon.
