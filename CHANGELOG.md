# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.0] - 2026-04-26

### Added

- **`SwiftEmailValidatorIDNA` companion target** — opt-in UTS #46 Unicode
  IDNA Compatibility Processing on the host portion of the address.
  Mirrors the `SwiftEmailValidatorUTS39` architecture: imported separately
  (`import SwiftEmailValidatorIDNA`) so the ~385 KB UCD-derived data
  doesn't bundle into callers that don't need it. Provides:
  - `IDNA.toAscii(_:options:)` / `IDNA.toUnicode(_:options:)` — direct
    UTS #46 §4 Map / NFC / Break / Validate / ToASCII pipeline.
  - `IDNA.domainValidator(_:base:)` factory and convenience overloads
    `EmailSyntaxValidator.correctlyFormatted(_:idna:)` /
    `mailbox(from:idna:)` chaining IDNA processing into the existing
    `domainValidator` slot.
  - `IDNA.Options` — `transitional` (default `false`, matches the
    post-2016 spec recommendation and modern browsers), `checkHyphens`,
    `useSTD3ASCIIRules`, `verifyDnsLength`, `checkBidi`, `checkJoiners`,
    `checkContextO`.
  - Self-contained RFC 3492 Punycode encoder/decoder with overflow
    guards on every multiply/add.
  - Bundled IDNA mapping table, Bidi_Class, Joining_Type, Virama, and
    Script tables — Unicode 17.0.0.
  - Generator pipeline at `Sources/SwiftEmailValidatorIDNA/Tools/`
    (`fetch-ucd.sh` + `generate.py`); regenerate only on UCD upgrades.
- **UTS #46 §4 V1-V7 validity criteria** all enforced by default:
  V1 NFC, V2 hyphen rules (leading/trailing + 3-4 with `xn--` carve-out),
  V3 leading combining mark rejection (Mn/Mc/Me), V4/V5 per-scalar
  status + `UseSTD3ASCIIRules` LDH gate, V6 `CheckBidi` (RFC 5893 §2),
  V7 `CheckJoiners` (RFC 5892 §A.1 ZWNJ + §A.2 ZWJ).
- **`UseSTD3ASCIIRules` enforcement at the validator layer.** The modern
  preprocessed IDNA Mapping Table classifies non-LDH ASCII (`_`, `/`,
  `:`, `@`, `*`, `<`, `>`, `"`, `$`, `+`, C0/DEL, …) as `valid` with the
  informational `NV8` tag, so STD3 cannot be inferred from the table
  status alone. The validator runs an explicit per-scalar LDH check on
  ASCII scalars after Step 1 mapping (so `U+FF0F` → `U+002F` is also
  caught) and after `xn--` decoding.
- **`VerifyDnsLength` enforcement** per UTS #46 §4.2 ToASCII step 5 /
  RFC 5890 §2.3.1: each A-label 1-63 octets, total domain 1-253 octets
  excluding any trailing root dot. Applied uniformly to every A-label,
  not just freshly Punycode-encoded ones, so a 64-char input ASCII
  label and an oversized `xn--` input are both caught. Empty trailing
  root labels rejected when on; preserved when off.
- **RFC 5893 §2 Bidi rule** (UTS #46 V6). Enforced on every label of
  any "Bidi domain name" (RFC 5893 §1.4: any label contains R/AL/AN).
  Pure-LTR siblings of RTL labels are also gated. All six conditions
  implemented (LTR-start vs RTL-start, condition 4 EN/AN exclusivity,
  trailing-NSM peeling for conditions 3/6).
- **RFC 5892 §A.1 / §A.2 CONTEXTJ rules** (UTS #46 V7). ZWNJ allowed
  when preceded by Virama (CCC=9) OR when sandwiched between L|D and
  R|D Joining_Type runs (T-class scalars transparent on both sides).
  ZWJ allowed only when preceded by Virama. Catches ZWJ/ZWNJ used
  outside legitimate joining contexts — a known homograph attack
  vector — while preserving Persian/Indic legitimate use.
- **RFC 5892 §A.3-§A.9 CONTEXTO rules** layered on top of UTS #46 §4
  as a security extension (default on, opt-out via
  `IDNA.Options.checkContextO: false`):
  - §A.3 `U+00B7` MIDDLE DOT only between two `'l'` (Catalan ela
    geminada).
  - §A.4 `U+0375` GREEK KERAIA only when followed by Greek script.
  - §A.5 / §A.6 `U+05F3` / `U+05F4` HEBREW GERESH / GERSHAYIM only
    when preceded by Hebrew script.
  - §A.7 `U+30FB` KATAKANA MIDDLE DOT only in labels also containing
    Hiragana, Katakana, or Han script.
  - §A.8 / §A.9 Arabic-Indic Digits (`U+0660..U+0669`) and Extended
    Arabic-Indic Digits (`U+06F0..U+06F9`) must not mix in the same
    label.

  Not required by UTS #46 §4 itself — added as a homograph-defense
  layer. Disable for strict UTS #46-only conformance.

### Tests

- **`IdnaTestV2DriverTests` conformance driver** runs the official
  Unicode `IdnaTestV2.txt` (v17.0.0) end-to-end across **toUnicode**,
  **toAsciiN** (Nontransitional), and **toAsciiT** (Transitional). All
  status code families (`Pn`, `Vn`, `An`, `Bn`, `Cn`, `Xn`, `U1`) are
  in scope: any row carrying any of them must be rejected by the
  implementation. CONTEXTO is disabled in the driver because UTS #46
  vectors are agnostic to it; CONTEXTO is exercised independently by
  `ContextOTests`. Driver covers >1000 vectors with 0 failures.
- New per-rule test files: `IDNAProcessingTests`, `BidiRuleTests`,
  `ContextJTests`, `ContextOTests`, `IDNAIntegrationTests`,
  `PunycodeTests`. Total IDNA test count: 102.

### Tooling

- **Mapping table stored as parallel primitive arrays** rather than
  `[(UInt32, UInt32, UInt8, UInt32, UInt8)]` tuples. The tuple-array
  form OOMed GitHub-hosted macOS CI runners during parallel module
  compilation alongside the UTS #39 data tables; flat arrays let the
  emit-module phase type-check each homogeneous primitive cheaply.
- **`Tools/generate.py`** emits five generated data files
  (`IdnaMapping.swift`, `BidiClass.swift`, `JoiningType.swift`,
  `Virama.swift`, `Script.swift`). Run only on UCD version upgrades;
  the generated Swift files are checked into source control.

### Benchmarks

- **Comparison table now grades each adapter within its declared RFC
  scope.** Previously every library was scored against the full corpus
  including UTS #39 / IDNA / RFC 6531 cases, penalizing libraries that
  never claimed to handle them. Adapters now declare their scope; the
  in-scope accuracy column is the headline metric, with a
  modern-superset column kept alongside for callers who care about
  beyond-scope coverage.
- Benchmark output refreshed for the IDNA companion target.

### Documentation

- README links the IETF Special-Use Domain RFCs (6761 / 6762 / 7686 /
  8375 / 9476) inline and surfaces the IDNA companion target in the
  intro section.
- `CLAUDE.md` and `SECURITY.md` refreshed for the 1.7.x architecture
  (three library targets: core / UTS #39 / IDNA).
- DemoApp corpus size reference corrected (150/195 → ~240).

## [1.6.1] - 2026-04-26

## [1.6.1] - 2026-04-26

### Security

This release closes a series of Unicode and RFC compliance gaps surfaced by
adversarial review of 1.6.0. All findings reduce permissiveness; no API
surface changed. Users on 1.6.0 should upgrade.

#### Default_Ignorable spoofing closure (RFC 5892 §2.6)

`CharacterSet.letters` on Darwin admits a number of `Default_Ignorable`
scalars that produce no glyph and are DISALLOWED in IDNA2008. Several
slipped through both the local-part and domain-label gates in 1.6.0:

- **Domain label path** now rejects `U+3164` HANGUL FILLER, `U+FE0F`
  VS-16, `U+E0100` VS-17 (SSP), `U+180B`–`U+180F` MONGOLIAN FREE
  VARIATION SELECTORS, `U+115F`/`U+1160` HANGUL CHOSEONG/JUNGSEONG
  FILLERS, `U+17B4`–`U+17B5` KHMER VOWEL INHERENT, and `U+FFA0`
  HALFWIDTH HANGUL FILLER. PVALID combining marks (e.g. `U+05B0`
  HEBREW POINT SHEVA) remain accepted; a canary test pins this.
- **Local-part path** now rejects `U+034F` COMBINING GRAPHEME JOINER,
  the SMP `U+1BCA0`–`U+1BCA3` SHORTHAND FORMAT controls, the
  `U+1D173`–`U+1D17A` MUSICAL SYMBOL formatting controls, and the
  reserved `U+FFF0`–`U+FFF8` block.
- **Leading combining marks rejected.** A label starting with an
  Mn/Mc/Me scalar (e.g. lone `U+0301`) is now rejected per-label in
  `extractDotAtom`. Mid-label combining marks remain accepted so
  legitimate diacritics (`a` + `U+0301` = `á`) still validate.

#### Validator behaviour fixes

- **Empty quoted local part rejected.** `""@x.com` is now rejected for
  parity with the dot-atom path. RFC 5321 §3.3 notes the empty
  local-part is "not generally treated as a deliverable address".
- **`.arpa` rejected by `TLDDomainValidator`.** RFC 3172 reserves the
  `.arpa` zone for DNS infrastructure (`in-addr.arpa`, `ip6.arpa`,
  `iris.arpa`); no MTA accepts mail there. `home.arpa` (RFC 8375)
  remains in `specialUseDomains` as defensive redundancy.
- **`TLDDomainValidator.isPubliclyDeliverable(_:)` two-layer split.**
  Direct callers passing hostnames with surrounding whitespace or
  IDNA-equivalent dot variants (`U+3002`, `U+FF0E`, `U+FF61`) used to
  receive an accept response because the function only inspected the
  rightmost ASCII-`.`-split label. The public form now trims and folds
  before dispatching to a raw `_isPubliclyDeliverable(_:)` worker.
  `EmailSyntaxValidator`'s LDH gate already protected the end-to-end
  pipeline; this hardens the `TLDDomainValidator` API in isolation.
- **IPv6 regex case + leading-zero gaps.** `_matchIPv6` accepted
  embedded-IPv4 octets with leading zeros (e.g. `192.168.001.001`)
  even though `_matchIPv4` correctly rejects them — same input got
  opposite verdicts depending on host shape (RFC 3986 §3.2.2). The
  IPv4-mapped prefix was also hardcoded lowercase `ffff`, rejecting
  `[IPv6:::FFFF:1.2.3.4]` (RFC 4291 §2.2 case-insensitivity). Both
  fixed; six octet patterns and the `[fF]{4}` prefix updated.

#### RFC 2047 encoder/decoder hardening

- **75-octet cap enforced on encoder output.** The decoder rejected
  over-length encoded-words but the encoder did not, so long Unicode
  inputs auto-encoded then re-decoded silently failed to round-trip.
  `encode()` now returns `nil` if the assembled `=?utf-8?b?<base64>?=`
  exceeds 75 chars (≈47 UTF-8 bytes), restoring encode→decode symmetry.
- **Base64 residue==1 rejected explicitly.** The padding table emitted
  illegal `===` for 1-byte residues; Foundation rejected the result
  by accident. Now `encode()` self-checks before relying on Foundation.
- **Encoded-text grammar tightened to `1*<text>`** per RFC 2047 §2.
  The third regex group changed from `(.*)` to `([^? ]+)`, rejecting
  empty payloads (`=?utf-8?b??=`) and literal `?` in encoded-text
  (`=?iso-8859-1?q?ab?cd?=`).

#### UTS #39 hardening

- **§5.2 Moderately Restrictive: second-script pool restricted to UAX #31
  Recommended scripts.** 1.6.0 enumerated all 174 scripts as candidate
  partners with Latin (excluding only Cyrl/Grek/Latn/Common/Inherited),
  so with `rejectRestrictedIdentifiers: false` Latin + Phoenician /
  Limbu / etc. were accepted. Replaced with a precomputed
  `moderatelyRestrictiveCandidateIDs` set built from the 26 Recommended
  scripts (minus Latn/Cyrl/Grek/Common/Inherited; Cherokee Limited_Use
  also excluded).
- **§5.1 Augmented_Script_Set applied in Single Script analysis.**
  `ScriptAnalyzer.isSingleScript` and `stringCompatible` previously used
  raw `Script_Extensions(X)`. Without §5.1 augmentation, pure-Japanese
  (Han + Hira + Kana, no Latin), pure-Korean (Han + Hang),
  pure-Chinese-with-Bopomofo (Han + Bopo), and even Hira + Kana strings
  were misclassified as multi-script at `.singleScript`. Highly
  Restrictive whitelist papered over Latin-included combos but not the
  no-Latin variants. Added `augmentedScriptSet(of:)` synthesizing
  virtual Hanb/Jpan/Kore IDs at `0x10000+` (UCD doesn't ship them as
  `Script_Extensions` values).

### Changed

- **`TLDDomainValidator` two-layer API.** Public
  `isPubliclyDeliverable(_:)` trims surrounding whitespace and folds
  `U+3002` / `U+FF0E` / `U+FF61` to ASCII `.` before dispatching to
  `_isPubliclyDeliverable(_:)`. The worker is `public` (with
  underscore-prefix marking module-internal use) only because Swift
  requires default-arg symbols of public functions to be public.

### Documentation

- **`.asciiWithUnicodeExtension` mode** documented as a project
  convention (whole-address RFC 2047 wrap), not standards-conformant
  SMTPUTF8 — RFC 2047 §5 forbids encoded-words inside `addr-spec`.
  Steers callers needing arbitrary-MTA interop to `.unicode` mode
  (RFC 6531).
- **`domainLabelCharacterSet`** documented as a coarse Letter+digit
  gate, not RFC 5891 §4.2.3.2 PVALID enforcement; strict IDNA2008 is
  delegated to the `domainValidator` closure.
- **UTS #39 docstrings** corrected: the `RestrictionLevel.highlyRestrictive`
  combos now match §5.2.2 Table 1 (Japanese, Korean, Chinese — not the
  prior incorrect "Latin + Han, Latin + Han + Hiragana + Katakana,
  Latin + Han + Hangul + Bopomofo"). Eight other references to
  non-existent §5.2.1/§5.2.2/§5.2.3 anchors switched to §5.2's
  named-bullet form.
- **UTS #39 out-of-scope sections documented** in the `UTS39`
  namespace docstring: §5.6.1 Whole-Script Confusables, §5.7.1
  Mixed-Numbers, and `Identifier_Type=Not_NFKC` pre-normalization
  (with caller workaround for the NFKC case).
- **EmailSyntaxValidator domain-length comment** rewritten to cite
  RFC 5321 §4.5.3.1.2 as the headline (255-octet wire cap) and explain
  how 253 is the derived presentation-form ceiling. Cap value
  (≤253) unchanged.

### Tooling

- **`Tools/generate_tlds.py` switched to PyPI `idna`** (IDNA2008 +
  RFC 3492 Punycode) from stdlib `encodings.idna` (IDNA2003,
  deprecation-flagged). Generator runs in maintainer/CI hands so the
  new pip dependency has zero consumer impact. The bundled
  `Generated/IANATLDs.swift` is byte-identical because all 151 IDN
  TLDs in the IANA root zone round-trip cleanly under both modes
  today, and the SHA-256 short-circuit detects no-op runs. The
  nightly workflow installs `idna` before invoking the script.

### Tests

- Test count grew from 272 to 299 (all passing).
- New coverage includes: Default_Ignorable rejection across BMP +
  SMP + combining-mark-position vectors, leading combining marks,
  IPv6 case-insensitivity and embedded-IPv4 leading zeros, RFC 6874
  percent-encoded zone IDs, IDN case-fold (`example.БЕЛ`), RFC 2047
  encoder structural shape and the 47/48-byte boundary,
  General-address-literal rejection (RFC 5321 §4.1.3), single-label
  host rejection through default validator wiring, and IPv4-mapped
  IPv6 literals end-to-end.
- Multiple weak assertions tightened across the suite (positive
  equality replacing `XCTAssertNotEqual`, wire-form pins for RFC 2047
  round-trips, `XCTAssertEqual` replacing one-way ASCII⇒Unicode
  invariant).
- DemoApp test corpus extended with 34 Default_Ignorable spoofing
  cases (33 negative + 1 PVALID canary). `swift run EmailBench`
  picks them up via the existing symlink.

## [1.6.0] - 2026-04-25

### Removed

- **`SwiftPublicSuffixList` dependency.** The package no longer pulls
  any third-party Swift dependency. The Public Suffix List was the wrong
  primitive for email validation: it was designed for cookie scoping and
  its multi-level / PRIVATE-section entries are policy artifacts of
  specific registries, with weekly churn driven by non-email concerns.

### Added

- **`TLDDomainValidator` (new public type).** Default domain validator
  used by `EmailSyntaxValidator`. Confirms the rightmost DNS label is a
  currently-delegated IANA TLD (ACE `xn--…` and Unicode U-label forms
  both accepted) and rejects names reserved by the IETF Special-Use
  Domain Names registry:
  - `.test` (RFC 6761 §6.2)
  - `.example`, `example.com`, `example.net`, `example.org` (RFC 6761 §6.5)
  - `.invalid` (RFC 6761 §6.4)
  - `.localhost` (RFC 6761 §6.3)
  - `.local` (RFC 6762 — mDNS)
  - `.onion` (RFC 7686 — Tor)
  - `.alt` (RFC 9476)
  - `home.arpa` (RFC 8375)

  Subdomains under any of these are also rejected.
- **`Sources/SwiftEmailValidator/Generated/IANATLDs.swift`** — bundled
  IANA TLD set (~1,400 ACE + ~150 U-label entries). Auto-generated; do
  not edit by hand.
- **`Tools/generate_tlds.py`** — Python 3 stdlib-only generator that
  fetches `https://data.iana.org/TLD/tlds-alpha-by-domain.txt`, expands
  ACE TLDs to U-labels via `encodings.idna.ToUnicode`, and writes the
  Swift source. Records source URL, fetch timestamp, and SHA-256.
- **`.github/workflows/update-tlds.yml`** — nightly workflow that
  refreshes the bundled TLD list and opens a PR if it changed.
- **`TLDDomainValidatorTests`** — new test class covering real TLDs,
  fake TLDs, special-use rejection, IDN handling, case insensitivity,
  trailing root dot, and wiring as the validator default.

### Changed

- **Default `domainValidator` closure** on
  `EmailSyntaxValidator.correctlyFormatted` and `mailbox(from:)` switched
  from
  `{ PublicSuffixList.isUnrestricted(PublicSuffixList.ace($0)) }`
  to
  `{ TLDDomainValidator.isPubliclyDeliverable($0) }`.
- **`UTS39.domainValidator(_:base:)` default base closure** likewise
  switched from PSL to `TLDDomainValidator`.
- **`EmailSyntaxValidator.correctlyFormatted(_:uts39:)` and
  `mailbox(from:uts39:)` convenience overloads** likewise switched.
- **README & benchmark output** rewritten to describe the new default
  and the rationale for moving off the PSL.

### Migration notes

- **Drop the dependency:** remove `SwiftPublicSuffixList` from your
  `Package.swift`. SwiftEmailValidator no longer requires it.
- **`@example.com` / `@example.net` / `@example.org`** now fail the
  default validator (RFC 6761 §6.5). If your tests or sample addresses
  used these, switch to a real public domain (`@iana.org` is stable) or
  pass a permissive `domainValidator: { _ in true }`.
- **`@localhost`, `@host.local`, intranet domains** also fail the
  default. Pass a custom `domainValidator` closure if your application
  accepts these — see "Domain validation" in the README.
- **PSL-based custom rules:** if you were calling
  `PublicSuffixList.isUnrestricted($0, rules: customRules)`, replace
  with your own closure (the test suite has examples of a simple
  TLD-allowlist closure in `LocalPartValidatorHookTests`).
- **Newly-delegated TLDs:** the bundled list ships frozen at the
  release SHA. The nightly GitHub workflow keeps the canonical copy
  current; downstream consumers waiting for a tagged release can
  override `domainValidator` with their own check or run
  `python3 Tools/generate_tlds.py` and ship the regenerated file.

## [1.5.0] - 2026-04-23

### Added

- **`SwiftEmailValidatorUTS39` companion library target.** New second
  `.library` product in `Package.swift` that layers
  [UTS #39](https://www.unicode.org/reports/tr39/) Unicode Security
  Mechanisms on top of the core validator. Callers who don't need it
  continue to `import SwiftEmailValidator` and pay no size cost; callers
  who want anti-spoofing add `import SwiftEmailValidatorUTS39` and opt
  in per call. All ~280 KB of UCD-derived data lives in the addon target.
  Covers:
  - **Identifier_Status filter** — rejects Restricted scripts
    (Linear B, Runic, Deseret, etc.).
  - **Mixed-script detection** — Single Script / Highly Restrictive /
    Moderately Restrictive per UTS #39 §5.2, using per-scalar
    `Script_Extensions ∩ target` intersection semantics.
  - **§4 confusable skeletons** — skeleton-equality against
    caller-supplied protected forms. Iterates map + NFD to a fixed
    point (confusables.txt has 13 non-idempotent entries requiring up
    to 3 iterations) and handles 48 multi-scalar NFD sources via a
    longest-match prefix table.
- **`localPartValidator` parameter** on `EmailSyntaxValidator.correctlyFormatted`
  and `mailbox(from:)`. Non-escaping closure applied to the semantic
  local-part string (dot-atom as-is, quoted-string cleaned/unescaped)
  after RFC parsing succeeds. Default `{ _ in true }` preserves existing
  behavior; this is the extension point the UTS #39 addon uses. Symmetric
  with the existing `domainValidator` closure.
- **`EmailSyntaxValidator.correctlyFormatted(_:uts39:)` and
  `mailbox(from:uts39:)` convenience overloads** (via extension in the
  addon target). Wire a `UTS39.Policy` into both the local-part and
  domain-label validators in one call.
- **`UTS39.Policy` struct** with four knobs: `level: RestrictionLevel`,
  `rejectRestrictedIdentifiers`, `rejectConfusables`, and caller-supplied
  `confusableSkeletons` / `confusableAllowlist` sets.

### Data pipeline

- **`Sources/SwiftEmailValidatorUTS39/Tools/generate.py` + `fetch-ucd.sh`.**
  Manual regeneration pipeline (not build-time) for producing
  `Data/{IdentifierStatus,Scripts,Confusables}.swift` from UCD 17.0.0.
  Re-run only on Unicode version upgrades; checked-in Swift files are
  the source of truth for downstream consumers.

### Tests

- Test count grew from 164 to 242 (all passing).
- **`LocalPartValidatorHookTests`** (7 cases) covering the new hook on
  the main library: default pass-through, rejection surfacing as `nil`,
  cleaned quoted-string semantic form, and interaction with
  auto-RFC2047 retry.
- **`SwiftEmailValidatorUTS39Tests`** (71 cases across 6 files):
  `IdentifierStatusTests`, `MixedScriptTests`,
  `RestrictionLevelEdgeCaseTests` (ICU-inspired boundary cases),
  `ConfusablesTests`, `ConfusablesSkeletonRegressionTests` (walks
  every entry in the generated confusables table, asserting
  `skeleton(source) == skeleton(target)` — this is the test that
  surfaced the non-transitive-closure and multi-scalar NFD bugs
  during implementation), `DomainLabelTests`, `ConvenienceAPITests`.

## [1.4.1] - 2026-04-23

### Fixed

- **IPv6 literal regex now accepts RFC 4291 §2.2 format 2** (six uncompressed
  hex groups followed by a trailing IPv4-in-dotted-decimal, e.g.
  `aaaa:aaaa:aaaa:aaaa:aaaa:aaaa:127.0.0.1`). The upstream regex this
  validator was derived from only recognised the compressed / IPv4-mapped
  forms (`::ffff:x.x.x.x`, `1::5:x.x.x.x`). Found by running each
  competitor library's own test corpus through SwiftEmailValidator; this
  was the single genuine gap surfaced by that reverse check (the other
  four disagreements were syntax-vs-policy differences caught by our
  default `domainValidator`).
- Address `valid.ipv6v4.addr@[IPv6:aaaa:aaaa:aaaa:aaaa:aaaa:aaaa:127.0.0.1]`
  now validates as expected. Max IPv6 literal length remains 45 octets —
  already within the `IPAddressSyntaxValidator` public-API length cap, no
  guard changes needed.
- Added `testIPv6Format2UncompressedWithEmbeddedIPv4` and
  `testIPv6Format2RejectsWrongGroupCount` regression tests; updated the
  boundary-form test. Test count is now 164.

## [1.4.0] - 2026-04-23

### Added

- **`IPAddressSyntaxValidator` public length-capped wrappers.** The public
  `match(_:)`, `matchIPv4(_:)`, and `matchIPv6(_:)` methods now apply a
  `utf8.count` guard before dispatching to the regex engine: 15 octets for
  IPv4 (max `255.255.255.255`), 45 octets for IPv6 (max
  `ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255`). Prior to this release
  these methods had no input-length bound, so a caller passing a
  multi-megabyte string would spend O(n) inside `NSRegularExpression`
  before the trailing `$` anchor failed — a potential denial-of-service
  vector for code paths that expose the validator to untrusted input
  directly (bypassing `EmailSyntaxValidator`, which already caps the
  whole address at 254 UTF-8 octets).
- **Internal raw matchers** `_match(_:)`, `_matchIPv4(_:)`, and
  `_matchIPv6(_:)` retain the pre-1.4.0 behaviour (no length guard) and
  are used by `EmailSyntaxValidator.extractHostLiteral` directly — the
  upstream address cap already bounds the input, so the hot path avoids
  a redundant second `utf8.count` check.
- **`Benchmarks/` SPM package.** A new standalone harness runs the
  195-case DemoApp corpus through every SPM-consumable Swift email
  validator we could locate (evanrobertson, MimeEmailParser, bdolewski's
  regex, jwelton-equivalent via `NSDataDetector`) and emits a Markdown
  accuracy table. Kept out of the main `Package.swift` so library
  consumers don't transitively pull the competitors. See the
  "Comparison with other Swift email validators" section in the README
  for the published results and the methodology.

### Security

- The length-capped public wrappers close the only input-length DoS
  vector found in a manual audit of the library's public API surface.
  `EmailSyntaxValidator` users were never exposed (it already caps the
  input upstream); the vector applied only to callers invoking
  `IPAddressSyntaxValidator` directly. No crashes were introduced;
  `EmailSyntaxValidator.correctlyFormatted(_:)` behaviour is unchanged.

## [1.3.1] - 2026-04-23

### Changed

- **SwiftPublicSuffixList dependency bumped to 3.1.0.** v3.0 tightened
  `PublicSuffixList.isUnrestricted(_:)` / `match(_:)` to reject non-ASCII
  hostnames — IDN labels must be in ACE (Punycode) form. The default
  `domainValidator` closure now calls `PublicSuffixList.ace(_:)` on the
  domain before dispatching to `isUnrestricted(_:)`, so Unicode IDN
  domains continue to validate exactly as they did on 1.3.0 with PSL 2.x.
- `Mailbox.Host.domain(...)` still carries the original user-facing
  string; only the validator dispatch uses the ACE form.

### Migration

Callers who pass a custom `domainValidator` closure to
`correctlyFormatted(_:)` / `mailbox(from:)` and rely on the PSL default
behavior via `PublicSuffixList.isUnrestricted(_:)` should wrap their call
site with `PublicSuffixList.ace(_:)` if the closure receives Unicode IDN
domains — e.g. `{ PublicSuffixList.isUnrestricted(PublicSuffixList.ace($0), rules: myRules) }`.

## [1.2.0] - 2026-04-22

### Security

This release consolidates a series of Unicode and RFC compliance fixes that
hardened the validator against spoofing, parser-confusion, and out-of-spec
inputs. Earlier 1.1.x versions accept characters and encoded sequences that
should be rejected; users should upgrade.

#### Unicode spoofing prevention (local part)

- **Zs-category space characters rejected.** U+00A0 (NO-BREAK SPACE),
  U+1680 (OGHAM SPACE MARK), U+2000–U+200A (EN QUAD … HAIR SPACE),
  U+202F (NARROW NO-BREAK SPACE), U+205F (MEDIUM MATHEMATICAL SPACE),
  U+3000 (IDEOGRAPHIC SPACE) are visually indistinguishable from U+0020 in
  most fonts and could be used to register lookalike accounts.
- **Reserved format character U+2065 rejected.** The previous block
  (U+2060–U+2064) left U+2065 reachable; the range is now U+2060–U+2065.
- **Plane 1–3 supplementary noncharacters rejected.** U+1FFFE/U+1FFFF,
  U+2FFFE/U+2FFFF, U+3FFFE/U+3FFFF (Unicode §23.7 permanently reserved
  noncharacters) are now blocked via explicit scalar guards.
- **Planes 4–13 (U+40000–U+DFFFF) rejected.** Entirely unassigned in
  Unicode; should never appear in interchange.
- **Full Supplementary Special-purpose Plane and Supplementary PUA
  rejected.** U+E0000–U+10FFFF blocked as a single guarded range, covering
  Tags, Variation Selectors Supplement, and Private Use Areas A/B.
- **Variation Selectors rejected.** U+FE00–U+FE0F are invisible combining
  characters that produce no glyph (same spoofing risk as ZWJ/ZWNJ).
- **U+FDD0–U+FDEF and U+FFFE/U+FFFF rejected.** BMP §23.7 permanently
  reserved noncharacters.

#### RFC 2047 decoder hardening

- **DEL (0x7F) rejected from Q-encoded content.** The prior
  `value >= 0x20` guard admitted 0x7F.
- **C1 control bytes (0x80–0x9F) rejected from Q-encoded ISO-8859-1/2
  content.** Previously decoded to U+0080–U+009F C1 controls, which RFC
  5198 §2 forbids in network interchange.
- **75-character encoded-word limit enforced** per RFC 2047 §2 (the prior
  limit allowed 76).
- **Underscore-as-space decoding** in Q encoding per RFC 2047 §4.2.

#### Quoted-string parser hardening

- **Per-scalar character-set check.** `extractQuotedString` now uses
  `unicodeScalars.allSatisfy` instead of `rangeOfCharacter` (which only
  inspected the first scalar of a grapheme cluster), preventing
  security-excluded scalars from slipping through as combining elements.
- **Escaped quoted-pair restricted to a single ASCII scalar** per RFC 5321
  (`quoted-pair = "\" (VCHAR / WSP)`).
- **Inline scalar guard** in `extractQuotedString` matches the dot-atom
  guard, ensuring identical security posture across both local-part forms.

#### IPv6 / address-literal hardening

- **Zone identifiers rejected** (e.g. `fe80::1%eth0`) per RFC 5321 §4.1.3.
- **Empty `IPv6:` literal, non-IPv6 strings after the `IPv6:` tag, and
  non-standard literal types (e.g. `[SMTP:…]`) are rejected**, with
  regression tests added.

### Fixed

- **CharacterSet construction order.** Foundation's `CharacterSet` has a
  bug where calling `.subtracting()` on a set containing supplementary
  Unicode planes corrupts the supplementary-plane bitmap. All exclusion
  sets are now subtracted before `supplementaryPlanes` is added via
  `.union()`. `unicodeNonCharacters`, `unicodeSpaceChars`, and
  `zeroWidthAndInvisibleChars` were updated to follow this rule.
- **Domain octet limits enforced** (RFC 1035 §2.3.4): per-label
  ≤63 octets, total domain ≤253 octets — measured in UTF-8 bytes, not
  character count.
- **Total email length enforced** at 254 UTF-8 bytes (RFC 5321 §4.5.3.1.3).
- **Quoted-string local part length enforced** at 64 UTF-8 bytes.
- **ASCII-only domain labels in `.ascii` mode.** Unicode U-labels are now
  rejected when `compatibility == .ascii`; Punycode (xn--…) labels remain
  accepted.
- **Source-route addresses rejected** (`@relay.host:user@domain`).
- **Empty host, double-`@`, empty domain labels, leading/trailing dots and
  hyphens in domain labels** are rejected regardless of the
  `domainValidator` closure.

### Documentation

- **`mailbox(from:)` and `correctlyFormatted(_:)` doc comments corrected.**
  Prior comments referenced a `strategy:` parameter and `ValidationStrategy`
  type that do not exist. Documentation now matches the actual `options:`
  parameter and `Options` enum.

### Tests

- Test count grew from 77 to 125 (all passing).
- New thematic coverage for: Zs space spoofing, supplementary
  noncharacters, Variation Selectors, the Unicode Tags block, source
  routes, address-literal edge cases, byte-vs-character length boundaries,
  RFC 2047 75-char limit and C1 rejection.

## [1.1.0] - 2025-12-19

### Added

#### DocC Documentation
- **EmailSyntaxValidator**: Class-level documentation with usage examples
- **Mailbox**: Struct and property documentation (`email`, `localPart`, `host`)
- **LocalPart/Host enums**: Case documentation for `dotAtom`, `quotedString`, `domain`, `addressLiteral`
- **Options enum**: Documentation for `autoEncodeToRfc2047` option
- **Compatibility enum**: Detailed documentation for `ascii`, `asciiWithUnicodeExtension`, `unicode` modes
- **RFC2047Coder**: Class documentation with encoding examples, `encode()` and `decode()` method documentation
- **IPAddressSyntaxValidator**: Class documentation explaining RFC 5321 context

#### New Unit Tests (48 tests across 3 files)

**EmailSyntaxValidatorTests.swift**
- `testLocalPartExactly63Characters` - Boundary test for 63-character local part
- `testLocalPartExactlyOneCharacter` - Minimum valid local part
- `testLocalPartEmptyString` - Empty local part rejection
- `testUnicodeLocalPartCharacterVsByteCount` - 30 four-byte Unicode chars (120 bytes, 30 chars)
- `testUnicodeLocalPartExceeds64Characters` - 65+ Unicode character rejection
- `testEmojiInLocalPart` - Emoji validation in Unicode mode
- `testCombiningMarksInLocalPart` - Diacritics and combining characters
- `testHighUnicodeRanges` - Characters beyond BMP (U+1D400+)
- `testZeroWidthCharacters` - ZWSP, ZWJ, ZWNJ handling
- `testBidirectionalOverrideCharacters` - RTL/LTR control character rejection
- `testC1ControlCharactersRejected` - C1 control character rejection (U+0080-U+009F)
- `testRFC2047EncodedWithIPv4AddressLiteral` - RFC2047 with IPv4 literal
- `testRFC2047EncodedWithIPv6AddressLiteral` - RFC2047 with IPv6 literal
- `testQuotedStringWithMultipleAtSymbols` - Multiple @ in quoted strings
- `testQuotedStringWithRFC2047Decoding` - RFC2047 decoded quoted strings
- `testAutoEncodeToRfc2047WithAddressLiteral` - Combined options testing
- `testCustomDomainValidatorAcceptsAnyDomain` - Permissive validator
- `testCustomDomainValidatorRejectsAllDomains` - Restrictive validator
- `testCustomDomainValidatorWithSpecificTLDs` - TLD-specific validation
- `testCustomDomainValidatorReceivesCorrectDomain` - Domain parameter verification
- `testCustomDomainValidatorWithUnicodeDomain` - IDN domain handling
- `testMultipleDotsInVariousPositions` - Valid multi-dot local parts
- `testSingleCharactersBetweenDots` - Minimal segments between dots
- `testMaxConsecutiveSpecialCharacters` - Consecutive special characters
- `testSpecialCharactersAtBoundaries` - Special chars at start/end of segments
- `testExtremelyLongLocalPart` - 1000 character local part rejection
- `testExtremelyLongDomain` - 500+ character domain handling
- `testVeryLongRFC2047EncodedString` - Near 76-char limit RFC2047
- `testManyUnicodeCharactersInLocalPart` - 64 diverse Unicode characters

**RFC2047CoderTests.swift**
- `testDecodingUTF16B` - Base64 with UTF-16 charset
- `testDecodingUTF32B` - Base64 with UTF-32 charset
- `testDecodingUTF16InvalidData` - Malformed UTF-16 rejection
- `testDecodingUTF32InvalidData` - Malformed UTF-32 rejection
- `testEncodeDecodeRoundTripSimpleASCII` - ASCII round-trip
- `testEncodeDecodeRoundTripUnicode` - Unicode round-trip
- `testEncodeDecodeRoundTripSpecialCharacters` - Special character round-trip
- `testDecodingLatin2QPolishCharacters` - Polish special characters
- `testDecodingLatin2QCzechCharacters` - Czech special characters
- `testDecodingLatin2InvalidControlCharacter` - Invalid byte handling
- `testEncodeEmptyString` - Empty string encoding
- `testDecodeWithMixedCaseCharset` - Case-insensitive charset
- `testDecodeWithMixedCaseEncoding` - Case-insensitive encoding type
- `testDecodeWithWhitespaceInEncodedWord` - Whitespace handling

**IPAddressValidatorTests.swift**
- `testIPv6ZoneIdentifiers` - Zone identifier rejection per RFC 5321
- `testIPv6LoopbackVariants` - `::1` variations
- `testIPv4MappedIPv6Extended` - `::ffff:` mapped addresses
- `testIPv4LeadingZeros` - Leading zeros handling
- `testEmptyIPAddressStrings` - Empty/whitespace rejection

### Changed

- **EmailSyntaxValidator.swift**: Reordered CharacterSet construction to work around Foundation bug where `.subtracting()` corrupts supplementary Unicode plane data. Supplementary planes (U+10000-U+10FFFF) are now added last, after all subtractions.

### Fixed

#### RFC 5321 Compliance
- **IPAddressSyntaxValidator.swift**: IPv6 zone identifiers (e.g., `fe80::1%eth0`) are now correctly rejected. Per RFC 5321 Section 4.1.3, zone identifiers are not valid in email address literals.

#### RFC 5198 Compliance
- **EmailSyntaxValidator.swift**: C1 control characters (U+0080-U+009F) are now rejected in Unicode mode. Per RFC 5198 Section 2, these control characters should be avoided in network interchange.

#### RFC 6531 Compliance
- **EmailSyntaxValidator.swift**: Fixed supplementary Unicode plane support (U+10000-U+10FFFF). Emoji, mathematical symbols, and other characters beyond the Basic Multilingual Plane now correctly validate in Unicode mode.

#### Security Improvements
- **EmailSyntaxValidator.swift**: Bidirectional formatting characters are now rejected:
  - Left-to-Right Mark / Right-to-Left Mark (U+200E-U+200F)
  - Directional embeddings and overrides (U+202A-U+202E)
  - Directional isolates (U+2066-U+2069)
  - Deprecated format characters (U+206A-U+206F)

  These characters can be exploited for homograph attacks and email spoofing.

### Technical Notes

#### CharacterSet Bug Workaround
Foundation's `CharacterSet` has a bug where calling `.subtracting()` on a set that includes supplementary Unicode planes (U+10000+) corrupts the supplementary plane data, even when the subtracted characters don't overlap. The workaround is to add supplementary planes as the final `.union()` call, after all `.subtracting()` operations are complete.

```swift
// WRONG - supplementary planes get corrupted by subsequent subtractions
let charset = baseSet
    .union(supplementaryPlanes)  // Added here...
    .subtracting(c1Controls)     // ...corrupted here

// CORRECT - add supplementary planes last
let charset = baseSet
    .subtracting(c1Controls)     // All subtractions first
    .union(supplementaryPlanes)  // Add supplementary planes last
```
