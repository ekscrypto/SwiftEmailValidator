![swift workflow](https://github.com/ekscrypto/SwiftEmailValidator/actions/workflows/swift.yml/badge.svg) [![codecov](https://codecov.io/gh/ekscrypto/SwiftEmailValidator/branch/main/graph/badge.svg?token=W9KO1BG8S0)](https://codecov.io/gh/ekscrypto/SwiftEmailValidator) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) ![Issues](https://img.shields.io/github/issues/ekscrypto/SwiftEmailValidator) ![Releases](https://img.shields.io/github/v/release/ekscrypto/SwiftEmailValidator)

# SwiftEmailValidator

A Swift implementation of an international email address syntax validator based on RFC822, RFC2047, RFC5321, RFC5322, RFC6531, RFC6532, UTS #39 and UTS #46.
Since email addresses are local @ remote the validator also includes `IPAddressSyntaxValidator` and a built-in `TLDDomainValidator` whose default policy implements the IETF Special-Use Domain Names registry: `.arpa` (RFC 3172), `.test` / `.example` / `.invalid` / `.localhost` (RFC 6761), `.local` (RFC 6762), `.onion` (RFC 7686), `home.arpa` (RFC 8375), and `.alt` (RFC 9476). See [Reference Documents](#reference-documents) for the full RFC list.

This Swift Package does not require an Internet connection at runtime and has **no third-party dependencies**. Default domain validation is built in (see [Domain validation](#domain-validation) below).

The package ships **three library products**: `SwiftEmailValidator` (core RFC syntax validation, always-on); `SwiftEmailValidatorUTS39` (opt-in Unicode Security Mechanisms — mixed-script detection, confusable skeletons, Identifier_Status filtering); and `SwiftEmailValidatorIDNA` (opt-in UTS #46 IDNA Compatibility Processing — full mapping table, NFC, ToASCII / ToUnicode via RFC 3492 Punycode). Each opt-in target carries its own bundled Unicode data (~280 KB for UTS #39, ~385 KB for IDNA) and is imported separately so the core library stays slim. See [SwiftEmailValidatorUTS39](#swiftemailvalidatoruts39-unicode-security-mechanisms) and [SwiftEmailValidatorIDNA](#swiftemailvalidatoridna-uts-46-idna-compatibility-processing) below.

## Installation
### Swift Package Manager (SPM)

You can use The Swift Package Manager to install SwiftEmailValidator by adding it to your Package.swift file:

    import PackageDescription

    let package = Package(
        name: "MyApp",
        targets: [],
        dependencies: [
            .Package(url: "https://github.com/ekscrypto/SwiftEmailValidator.git", .upToNextMajor(from: "1.7.0"))
        ]
    )

Then depend on **one or both** library products from your target:

    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "SwiftEmailValidator", package: "SwiftEmailValidator"),
            // Opt in only if you need UTS #39 Unicode Security checks:
            .product(name: "SwiftEmailValidatorUTS39", package: "SwiftEmailValidator"),
            // Opt in only if you need UTS #46 IDNA Compatibility Processing:
            .product(name: "SwiftEmailValidatorIDNA", package: "SwiftEmailValidator"),
        ])

## Domain validation

By default, domains are validated by `TLDDomainValidator.isPubliclyDeliverable(_:)`, which:

1. Confirms the rightmost DNS label is a currently-delegated **IANA TLD** (both ACE `xn--…` and Unicode U-label forms accepted).
2. Rejects names reserved by the **IETF Special-Use Domain Names registry** (RFC 6761, RFC 6762, RFC 7686, RFC 8375, RFC 9476):

   | Reserved | RFC | Notes |
   |---|---|---|
   | `.test` | 6761 §6.2 | Testing only |
   | `.example`, `example.com`, `example.net`, `example.org` | 6761 §6.5 | Reserved for documentation |
   | `.invalid` | 6761 §6.4 | Always invalid |
   | `.localhost` | 6761 §6.3 | Loopback |
   | `.local` | 6762 | mDNS / link-local |
   | `.onion` | 7686 | Tor hidden services |
   | `.alt` | 9476 | Non-DNS use |
   | `home.arpa` | 8375 | Homenet |

   Subdomains under any of these are also rejected.

### Why not the Public Suffix List?

The PSL was designed for **cookie scoping**, not email deliverability. Its multi-level entries (`co.uk`, `github.io`, `vercel.app`) are policy artifacts of specific registries, change weekly, and the PRIVATE section in particular has nothing to do with mail delivery. The IANA root zone is the canonical source for "is this label a delegated TLD?" — much smaller (~1.4 k entries) and updated only when ICANN delegates new TLDs.

`SwiftEmailValidator` previously depended on `SwiftPublicSuffixList`; that dependency was removed in **1.6.0**. See [CHANGELOG](CHANGELOG.md#160) for the migration path.

### Keeping the IANA list fresh

The bundled list is generated from the [IANA root zone TLD file](https://data.iana.org/TLD/tlds-alpha-by-domain.txt) by `Tools/generate_tlds.py`. A nightly GitHub workflow refreshes `Sources/SwiftEmailValidator/Generated/IANATLDs.swift` and opens a PR if the upstream list changed. Run locally to refresh on demand:

```bash
python3 Tools/generate_tlds.py
```

For applications that need a more recent snapshot than the released package ships with, override the `domainValidator` closure with your own check.

### Customizing or bypassing domain validation

Pass a custom `domainValidator` closure to validate against your own rules — for intranet domains, dev environments, or any policy that differs from "publicly deliverable":

```swift
// Intranet — accept anything
EmailSyntaxValidator.correctlyFormatted(
    "user@mail.corp",
    domainValidator: { _ in true })

// Custom allowlist
let allowedTLDs: Set<String> = ["com", "org"]
EmailSyntaxValidator.correctlyFormatted(
    "user@example.com",
    domainValidator: { domain in
        domain.lowercased().split(separator: ".").last
            .flatMap { allowedTLDs.contains(String($0)) } ?? false
    })
```

## Classes & Usage

### EmailSyntaxValidator

Simple use-cases:

    if EmailSyntaxValidator.correctlyFormatted("email@example.com") {
        print("email@example.com respects Email syntax rules")
    }

    if let mailboxInfo = EmailSyntaxValidator.mailbox(from: "santa.claus@northpole.com") {
        // mailboxInfo.email == "santa.claus@northpole.com"
        // mailboxInfo.localPart == .dotAtom("santa.claus")
        // mailboxInfo.host == .domain("northpole.com")
    }
    
    if let mailboxInfo = EmailSyntaxValidator.mailbox(from: "\"Santa Claus\"@northpole.com") {
        // mailboxInfo.email == "\"Santa Claus\"@northpole.com"
        // mailboxInfo.localPart == .quotedString("Santa Claus")
        // mailboxInfo.host == .domain("northpole.com"")
    }

Allowing IPv4/IPv6 addresses
    
    if EmailSyntaxValidator.correctlyFormatted("email@[127.0.0.1]", allowAddressLiteral: true) {
        print("email@[127.0.0.1] also respects since address literals are allowed")
    }
    
    if let mailboxInfo = EmailSyntaxValidator.mailbox(from: "email@[IPv6:fe80::1]", allowAddressLiteral: true) {
        // mailboxInfo.email == "email@[IPv6:fe80::1]"
        // mailboxInfo.localPart == .dotAtom("email")
        // mailboxInfo.host == .addressLiteral("IPv6:fe80::1")
    }

Validating Unicode emails encoded into ASCII (RFC2047):
    
    if let mailboxInfo = EmailSyntaxValidator.mailbox(from: "=?utf-8?B?7ZWcQHgu7ZWc6rWt?=", compatibility: .asciiWithUnicodeExtension) {
        // mailboxInfo.email == "=?utf-8?B?7ZWcQHgu7ZWc6rWt?="
        // mailboxInfo.localpart == .dotAtom("한")
        // mailboxInfo.host == .domain("x.한국")
    }

Validating Unicode emails with auto-RFC2047 encoding:

    if let mailboxInfo = EmailSyntaxValidator.mailbox(from: "한@x.한국", options: [.autoEncodeToRfc2047], compatibility.asciiWithUnicodeExtension) {
        // mailboxInfo.email == "=?utf-8?b?7ZWcQHgu7ZWc6rWt?="
        // mailboxInfo.localpart == .dotAtom("한")
        // mailboxInfo.host == .domain("x.한국")
    }

Forcing ASCII-only compatibility:

    if !EmailSyntaxValidator.correctlyFormatted("한@x.한국", compatibility: .ascii) {
        // invalid email for ASCII-only support
    }
    
    if EmailSyntaxValidator.correctlyFormatted("hello@world.net", compatibility: .ascii) {
        // Email is valid for ASCII-only systems
    }
    
#### Custom domain validation

Every `EmailSyntaxValidator` entry point accepts a `domainValidator: (String) -> Bool` closure that defaults to `TLDDomainValidator.isPubliclyDeliverable(_:)`. Return `true` to accept the domain, `false` to reject. See [Domain validation](#domain-validation) above for the full list of options.

    // Restrict to a custom allowlist:
    let allowedTLDs: Set<String> = ["com"]
    if let mailboxInfo = EmailSyntaxValidator.mailbox(
        from: "santa.claus@northpole.com",
        domainValidator: { domain in
            domain.lowercased().split(separator: ".").last
                .flatMap { allowedTLDs.contains(String($0)) } ?? false
        }) {
        // mailboxInfo.localPart == .dotAtom("santa.claus")
        // mailboxInfo.host == .domain("northpole.com")
    }

    // Bypass domain validation entirely (intranet / freeform hosts):
    if let mailboxInfo = EmailSyntaxValidator.mailbox(
        from: "santa.claus@Ho Ho Ho North Pole",
        domainValidator: { _ in true }) {
        // mailboxInfo.localPart == .dotAtom("santa.claus")
        // mailboxInfo.host == .domain("Ho Ho Ho North Pole")
    }

### EmailNormalizer

Two Unicode normalization helpers, intentionally separate from `EmailSyntaxValidator`
(normalization and validation are composable but distinct concerns):

* **`EmailNormalizer.nfc(_:)`** — Unicode **NFC** (Canonical Composition). Collapses canonically-
  equivalent sequences such as decomposed `e` + ◌́ → precomposed `é`, but leaves compatibility
  variants (fullwidth, ligatures, superscripts) alone. This is the form prescribed by
  **RFC 6532 §3.1** for internationalized header-field comparison and by **RFC 5198** for
  network interchange. Use it when you need a spec-compliant comparison key, or when you
  intend to preserve the address for display, forwarding, or reply-to.
* **`EmailNormalizer.nfkc(_:)`** — Unicode **NFKC** (Compatibility Composition). Additionally
  folds compatibility variants: fullwidth `＠` → `@`, ligature `ﬁ` → `fi`, superscript `²` → `2`.
  Use it for **anti-spoofing** or **account de-duplication** (matching Gmail/Outlook behaviour).
  RFC 6532 §3.1 explicitly says NFKC **SHOULD NOT** be used, because compatibility folding can
  destroy information needed to spell some names correctly. This library nevertheless ships it
  as a documented deliberate deviation, because the de-duplication use case is common and
  important. Use `nfc(_:)` if you need spec compliance or name-preservation fidelity.

Both methods are pure Unicode transforms — they do not validate, do not lowercase, and do not
strip whitespace. Pipe the output into the validator when you want both:

    import SwiftEmailValidator

    // Anti-spoofing pipeline (NFKC)
    let rawInput   = "ｕｓｅｒ＠example.com"           // fullwidth letters and '@'
    let dedupKey   = EmailNormalizer.nfkc(rawInput)   // → "user@example.com"
    if EmailSyntaxValidator.correctlyFormatted(dedupKey) {
        // Store / compare `dedupKey`, not `rawInput`.
    }

    // Spec-compliant pipeline (NFC, RFC 6532 §3.1)
    let canonical  = EmailNormalizer.nfc(rawInput)    // → "ｕｓｅｒ＠example.com" (unchanged: NFC
                                                      //    does not fold fullwidth)

What `EmailNormalizer` does **not** do:

* It does not validate syntax — normalization is a pure Unicode transform.
* It does not lowercase — RFC 5321 §2.4 declares local parts case-sensitive.
* It does not strip whitespace or perform any sanitization.

#### Length is not preserved (NFKC)

NFKC can substantially expand a string. `U+FDFA` (ARABIC LIGATURE SALLALLAHOU ALAYHE WASALLAM)
expands to 18 scalars / 33 UTF-8 octets and contains ASCII SPACE characters. A short input can
therefore exceed the 64-octet local-part limit (RFC 5321 §4.5.3.1.1) after normalization.
**Always validate after normalizing, never the other way round.** NFC is effectively length-
stable in practice and does not have this hazard.

#### Behaviour inside quoted-string local parts

Both forms are applied to the whole address as a single Unicode stream. This is **safe
structurally**: the RFC 5321 delimiters `"` (U+0022), `\` (U+005C), and `@` (U+0040) are ASCII,
and NFC/NFKC are no-ops on ASCII. The quoting structure is preserved and the output parses the
same way as the input.

For NFKC, non-ASCII content *between* the quotes is also normalized — **deliberately**, because
the primary motivation is spoofing / account de-duplication and an attacker who wraps a
homograph in quotes would otherwise sidestep the check:

    // All three of these collapse to the same canonical form after nfkc(_:):
    EmailNormalizer.nfkc("admin@example.com")           // "admin@example.com"
    EmailNormalizer.nfkc("ａｄｍｉｎ@example.com")       // "admin@example.com"
    EmailNormalizer.nfkc(#""ａｄｍｉｎ"@example.com"#)   // #""admin"@example.com"#

If your application needs the *exact* scalar sequence inside a quoted local part preserved,
parse the address first with `EmailSyntaxValidator.mailbox(from:)` and apply normalization
only to the components you choose to canonicalize.

### SwiftEmailValidatorUTS39 (Unicode Security Mechanisms)

An **opt-in companion library** (second `.library` product in `Package.swift`)
that layers [UTS #39](https://www.unicode.org/reports/tr39/) Unicode Security
Mechanisms on top of the core validator. The addon ships ~280 KB of
UCD-derived data (Identifier_Status, Script_Extensions, §4 confusables) which
stays entirely inside the companion target, so `import SwiftEmailValidator`
alone pays no size cost.

Three mechanisms are available, composable via `UTS39.Policy`:

* **Identifier_Status filter** — rejects scalars marked `Restricted` by
  UTS #39 (obscure or historic scripts like Linear B, Runic, Deseret).
  On by default.
* **Mixed-script detection** — classifies the string against the
  UTS #39 §5.2 Restriction Level ladder: Single Script / Highly Restrictive /
  Moderately Restrictive. Catches the classic homograph vectors
  (Latin + Cyrillic `а`, Latin + Greek `ο`). Default level is
  `.highlyRestrictive`, matching Google's published identifier-security
  guidance.
* **§4 confusable skeletons** — computes the skeleton of a candidate
  string and compares it against caller-supplied **protected forms**
  (brand names, reserved account handles, etc.). Off by default — enable
  per call.

#### Simple use — the convenience API

```swift
import SwiftEmailValidator
import SwiftEmailValidatorUTS39

// Default policy: Highly Restrictive + Identifier_Status filter on,
// confusables off. Checks both local part and each domain label.
if EmailSyntaxValidator.correctlyFormatted("alice@example.com", uts39: .init()) {
    // Accepted: single-script Latin, registered public suffix.
}

// Classic Cyrillic-а homograph — rejected by mixed-script detection.
EmailSyntaxValidator.correctlyFormatted("p\u{0430}ypal@example.com",
                                        uts39: .init())
// false

// Japanese mixed script — accepted per Highly Restrictive
// whitelist (Latin + Han + Hiragana + Katakana).
EmailSyntaxValidator.correctlyFormatted("user会社カナ@example.com",
                                        uts39: .init())
// true
```

The same overload exists for `mailbox(from:uts39:)`:

```swift
if let mb = EmailSyntaxValidator.mailbox(from: "ユーザー@example.com",
                                         uts39: .init()) {
    // mb.localPart == .dotAtom("ユーザー")  (single-script Katakana)
}
```

#### Tuning the policy

```swift
var policy = UTS39.Policy()
policy.level = .singleScript              // stricter than the default
policy.rejectRestrictedIdentifiers = true // default

// Protect specific brand names against whole-script confusables:
policy.rejectConfusables = true
policy.confusableSkeletons = ["paypal", "google", "apple"]
// An allowlist exempts known-safe strings that would collide at skeleton level:
policy.confusableAllowlist = ["paypal"] // the literal protected form itself

EmailSyntaxValidator.correctlyFormatted(candidate, uts39: policy)
```

#### Selecting a Restriction Level

```swift
.singleScript           // The intersection of Script_Extensions across all
                        // scalars is non-empty. Pure Latin, pure Cyrillic,
                        // pure Han all pass. Mixing any two distinct
                        // scripts (outside Common/Inherited) fails.

.highlyRestrictive      // Recommended default. Adds these whitelisted combos:
                        //   Latin + Han + Hiragana + Katakana  (Japanese)
                        //   Latin + Han + Hangul               (Korean)
                        //   Latin + Han + Bopomofo             (Chinese zhuyin)

.moderatelyRestrictive  // Highly Restrictive + Latin plus any single other
                        // Recommended script, except Cyrillic and Greek
                        // (too confusable with Latin per UTS #39 §5.2.3).
```

#### Lower-level: composing the closures yourself

If you need the pieces independently (e.g. validating just a local part, or
attaching UTS #39 to a non-default `domainValidator`), build the closures
directly:

```swift
let policy = UTS39.Policy()

EmailSyntaxValidator.correctlyFormatted(
    candidate,
    domainValidator: UTS39.domainValidator(policy),        // TLDDomainValidator + UTS #39 per label
    localPartValidator: UTS39.localPartValidator(policy))  // UTS #39 on the local part
```

`UTS39.domainValidator(_:base:)` accepts a custom base closure — by default
it wraps `TLDDomainValidator.isPubliclyDeliverable(_:)`:

```swift
let allowedTLDs: Set<String> = ["com", "net"]
let domainValidator = UTS39.domainValidator(policy, base: { domain in
    domain.lowercased().split(separator: ".").last
        .flatMap { allowedTLDs.contains(String($0)) } ?? false
})
```

#### The hook on the core library

The core `EmailSyntaxValidator` exposes a `localPartValidator: (String) -> Bool`
closure (default `{ _ in true }`) that the addon plugs into. You can use it
directly to attach any per-address policy you control, without depending on
the UTS #39 target:

```swift
import SwiftEmailValidator

// Reject any local part over 30 characters (a product policy, not an RFC rule).
EmailSyntaxValidator.correctlyFormatted(
    candidate,
    localPartValidator: { $0.count <= 30 })
```

The closure receives the **semantic** local-part string: a dot-atom as-is, or
a quoted-string in its **cleaned (unescaped, unquoted)** form — so
`"a\"b"@example.com` reaches the closure as `a"b`, not `"a\"b"`.

### SwiftEmailValidatorIDNA (UTS #46 IDNA Compatibility Processing)

`SwiftEmailValidatorIDNA` is an **opt-in** companion library that runs
[UTS #46](https://www.unicode.org/reports/tr46/) Unicode IDNA Compatibility
Processing on the host part of the address before the base domain check.
It bundles the full IDNA Mapping Table and a self-contained
[RFC 3492](https://datatracker.ietf.org/doc/html/rfc3492) Punycode codec.

What it gives you, beyond the core `TLDDomainValidator`:

* **Case-folding and width-folding** — `User@EXAMPLE.com`, `User@ｅｘａｍｐｌｅ.com`,
  and `User@example.com` all reach the IANA TLD lookup as `example.com`.
* **U-label ↔ A-label** — `user@münchen.de` and `user@xn--mnchen-3ya.de`
  are recognized as the same host.
* **Mapping-table conformance** — non-LDH ASCII, deprecated controls,
  and IDNA-`disallowed` scalars are rejected per the current Unicode
  release (currently 17.0.0).
* **Transitional vs Nontransitional** — switch via `IDNA.Options(transitional:)`.
  Default is **nontransitional** (post-2016 spec recommendation; matches
  modern browsers): `ß`, `ς`, ZWJ and ZWNJ are kept rather than mapped.

```swift
import SwiftEmailValidator
import SwiftEmailValidatorIDNA

let opts = IDNA.Options()  // nontransitional, CheckHyphens on, UseSTD3 on

// Convenience: IDNA processing chained to TLDDomainValidator.
EmailSyntaxValidator.correctlyFormatted("user@münchen.de", idna: opts)
// → true (Punycode-encoded host clears the IANA TLD check via .de)

// Direct ToASCII / ToUnicode for hosts.
IDNA.toAscii("ｅｘａｍｐｌｅ.com")        // "example.com"
IDNA.toAscii("münchen.de")             // "xn--mnchen-3ya.de"
IDNA.toUnicode("xn--mnchen-3ya.de")    // "münchen.de"
```

`IDNA.domainValidator(_:base:)` builds a closure suitable for the
`domainValidator:` parameter on the core `correctlyFormatted` /
`mailbox(from:)` calls. By default it chains to
`TLDDomainValidator._isPubliclyDeliverable`; pass `base: { _ in true }`
to use IDNA alone (e.g. for intranet hosts).

```swift
let domainValidator = IDNA.domainValidator(IDNA.Options(), base: { _ in true })
EmailSyntaxValidator.correctlyFormatted(
    "user@müller.intranet",
    domainValidator: domainValidator)
```

#### Intentionally out of scope for this initial release

* **Bidi rule** ([RFC 5893](https://datatracker.ietf.org/doc/html/rfc5893) §2). Mixed-direction
  labels are not detected. Most SMTP/DNS infrastructure does not enforce
  Bidi either, so the practical interoperability gap is narrow.
* **CONTEXTJ / CONTEXTO** ([RFC 5892](https://datatracker.ietf.org/doc/html/rfc5892) §A). ZWJ/ZWNJ in
  joining contexts and Greek-keraia / Hebrew-geresh / Hebrew-gershayim /
  Katakana-middle-dot context rules are not enforced — ZWJ and ZWNJ are
  treated as `valid` per nontransitional processing.
* **`UseSTD3ASCIIRules` enforcement at the validator level**. The bundled
  mapping table already classifies non-LDH ASCII as `disallowed`, so the
  flag is currently advisory and exposed for forward compatibility.

Layer your own check on top of `IDNA.toAscii(_:)` output if you need any
of the deferred mechanisms.

### IPAddressSyntaxValidator

    if IPAddressSyntaxValidator.matchIPv6("::1") {
        print("::1 is a valid IPv6 address")
    }

    if IPAddressSyntaxValidator.matchIPv4("127.0.0.1") {
        print("127.0.0.1 is a valid IPv4 address")
    }
    
    if IPAddressSyntaxValidator.match("8.8.8.8") {
        print("8.8.8.8 is a valid IP address")
    }
    
    if IPAddressSyntaxValidator.match("fe80::1") {
        print("fe80::1 is a valid IP address")
    }


### RFC2047Decoder
Allows to decode ASCII-encoded Latin-1/Latin-2/Unicode email addresses from SMTP headers

    print(RFC2047Decoder.decode("=?iso-8859-1?q?h=E9ro\@site.com?=")) 
    // héro@site.com
    
    print(RFC2047Decoder.decode("=?utf-8?B?7ZWcQHgu7ZWc6rWt?="))
    // 한@x.한국

## Known Behaviors

### Single-label domains (`user@localhost`)

RFC 5321 requires a fully-qualified domain name in the `RCPT TO` / `MAIL FROM` path, so single-label hostnames such as `localhost` or `mailserver` are not valid in standard SMTP.

The validator itself only checks syntax; whether a domain is accepted ultimately depends on the `domainValidator` closure. The default closure (`TLDDomainValidator.isPubliclyDeliverable`) rejects single-label names because they aren't fully-qualified. If you supply a permissive custom validator (`{ _ in true }`) single-label domains will be accepted. Make sure your validator enforces whatever hostname policy your application requires.

### Unicode normalization

The validator treats email addresses as opaque byte sequences and does **not** apply Unicode normalization (NFC/NFKC) before or after validation. This is intentional and RFC-correct: RFC 6531 explicitly leaves normalization to the receiving mail system.

A practical consequence is that visually identical addresses can be treated as distinct:

    // These two look the same on screen but are different strings:
    let precomposed  = "café@example.com"          // é as U+00E9 (precomposed)
    let decomposed   = "cafe\u{0301}@example.com"  // e + U+0301 combining acute (decomposed)

    // Both are valid — but they compare as unequal:
    precomposed == decomposed  // false

If your application needs to treat these as the same address (e.g., for de-duplication or lookup), normalize the input with `EmailNormalizer.nfc(_:)` (RFC 6532 §3.1) before validating:

    let normalized = EmailNormalizer.nfc(rawInput)
    let isValid = EmailSyntaxValidator.correctlyFormatted(normalized)

For anti-spoofing of fullwidth/ligature variants (e.g. `ａｄｍｉｎ` → `admin`), use `EmailNormalizer.nfkc(_:)` instead — see [EmailNormalizer](#emailnormalizer) above.

### Halfwidth and fullwidth Unicode forms

Unicode contains a "Fullwidth" block (U+FF01–U+FF5E) whose characters are visually similar to
ASCII printable characters — for example, `ａ` (U+FF41) resembles `a` (U+0061). These are valid
Unicode characters with legitimate uses in CJK typography and are accepted by the validator in
`.unicode` compatibility mode per RFC 6531.

This can create homograph confusion in account-registration systems:

    // Both pass validation, but are distinct strings:
    let ascii    = "admin@example.com"
    let fullwide = "ａｄｍｉｎ@example.com"   // local part uses U+FF41–U+FF4E

This is an **account-uniqueness concern**, not a syntax concern. The recommended mitigation for
registration systems is NFKC normalization, which maps fullwidth characters back to their ASCII
equivalents before storage or comparison. Use `EmailNormalizer.nfkc(_:)` — see
[EmailNormalizer](#emailnormalizer) below.

If your application must restrict local parts to ASCII-range characters exclusively, use
`.ascii` compatibility mode:

    EmailSyntaxValidator.correctlyFormatted(candidate, compatibility: .ascii)

## Comparison with other Swift email validators

**Last run:** 2026-04-26 &middot; **Toolchain:** Swift 6.3.1, macOS 26.4.1 (arm64) &middot; **Harness:** [`Benchmarks/`](Benchmarks/)

The `Benchmarks/` SPM package runs the 243-case DemoApp corpus
(`DemoApp/EmailValidation/Data/TestData.swift`, mirrored verbatim into
`Benchmarks/Sources/EmailBench/TestData.swift`) through every competitor
library we could consume as an SPM dependency. The harness is kept in a
separate package so consumers of SwiftEmailValidator do not transitively
pull the competitor dependencies.

### Libraries tested

| Library | Tested revision | RFC coverage | Domain validation |
|---|---|---|---|
| [SwiftEmailValidator](https://github.com/ekscrypto/SwiftEmailValidator) (this package) | 1.7.0 | RFC 822 / 2047 / 5321 / 5322 / 6531 | ✅ IANA TLD + RFC 6761 special-use blocklist (pluggable via `domainValidator:`) |
| [evanrobertson/EmailValidator](https://github.com/evanrobertson/EmailValidator) | `master` @ `ff80978` (untagged) | RFC 5322; optional i18n (RFC 653x) via `allowInternational:` | — |
| [igorrendulic/MimeEmailParser](https://github.com/igorrendulic/MimeEmailParser) | 1.0.5 | RFC 5322 + RFC 2047 / 6532 | — |
| [bdolewski/SwiftEmailValidator](https://github.com/bdolewski/SwiftEmailValidator) | `master` @ `85a0fc1` (regex vendored: the library's `EmailValidator` symbol has default/`internal` access and cannot be imported) | RFC 5322 (single regex) | — |
| [jwelton/EmailValidator](https://github.com/jwelton/EmailValidator) | `master` @ `26946d9` (emulated via `NSDataDetector` to avoid a package-identity collision with evanrobertson's `EmailValidator`) | Apple `NSDataDetector` link detection (no documented RFC target) | — |

Excluded from the harness:

* **swift-standards/swift-emailaddress-standard** — its manifest uses
  `.package(path: "../../swift-ietf/…")` and pins macOS 26; it is not
  consumable as a Git SPM dependency.
* **SwiftValidator / SwiftValidators / adamwaite-Validator** — general-purpose
  form-field validators rather than RFC-focused email parsers.

### Methodology

* Each adapter declares a **reference mode** from the DemoApp's
  `ValidationMethod` enum (e.g. `evanrobertson/EmailValidator (international)`
  is compared against `.swiftEmailUnicode` expectations because that mode
  accepts non-ASCII local parts). The DemoApp's per-case `expectedOverrides`
  map is then consulted to derive the ground truth for each `(case, adapter)`
  pair.
* Several competitor libraries call Swift's `fatalError` on adversarial
  inputs (out-of-bounds string indexing in their own parsers). `fatalError`
  cannot be caught in-process, so those inputs are listed in
  [`Benchmarks/Sources/EmailBench/SkipList.swift`](Benchmarks/Sources/EmailBench/SkipList.swift)
  and omitted from the library's accuracy denominator. The harness surfaces
  skipped counts + the input that crashed the library in a separate section
  of the report — they are **not** silently treated as failures or passes.

Reproduce:

```bash
cd Benchmarks
swift run -c release EmailBench              # prints the table below
swift run -c release EmailBench --verbose    # also lists every failing case
```

See [`Benchmarks/README.md`](Benchmarks/README.md) for the crash-discovery
loop used to populate the skip list.

### Results (243-case corpus)

Each library is graded two ways: against only the cases inside the standards
**it declares it implements** (`In-scope accuracy`), and against the full
superset of modern requirements (`Modern accuracy`). The two columns sit
side-by-side in the [results table below](#results-within-declared-scope) so
"reliable within its lane" and "covers a modern validator's responsibilities"
are visible at a glance. The capability framework that grounds those two
views follows.

### What a modern email validator should support

The `Modern accuracy` column grades every library against the same superset
expectation: a modern validator should handle the full stack of standards
governing email syntax and Unicode safety. Concretely:

| Capability | Standard | What it covers |
|---|---|---|
| Core syntax | **RFC 5322** | dot-atom, quoted-string, address-literal grammar, length boundaries |
| SMTP framing & literals | **RFC 5321** | 64-octet local-part cap, IPv4 / IPv6 address-literal grammar |
| Internationalized mail | **RFC 6531 / 6532** | UTF-8 local-part and domain (SMTPUTF8) |
| Encoded-word | **RFC 2047** | `=?charset?B/Q?text?=` decoding before validation |
| Domain policy | **RFC 6761 / 6762 / 7686 / 8375 / 9476** + IANA TLD root zone | reject `.example`, `.test`, `.invalid`, `.localhost`, `.local`, `.onion`, `home.arpa`, `.alt`, and labels not present in the IANA root zone |
| Unicode hardening | **UTS #39 / UAX #31 / RFC 6532 §3** | reject bidi controls, default-ignorable scalars, zero-width characters, leading combining marks, tag characters, supplementary-plane attacks |

A library is free to declare a narrower scope — that's what the next two
tables surface.

### Declared capability matrix

| Library | RFC 5322 | RFC 5321 | RFC 6531 | RFC 2047 | Domain | Hardening |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| SwiftEmailValidator (ASCII) | ✅ | ✅ | — | — | ✅ | ✅ |
| SwiftEmailValidator (ASCII + RFC 2047) | ✅ | ✅ | — | ✅ | ✅ | ✅ |
| SwiftEmailValidator (Unicode) | ✅ | ✅ | ✅ | — | ✅ | ✅ |
| evanrobertson/EmailValidator (ASCII) | ✅ | ✅ | — | — | — | — |
| evanrobertson/EmailValidator (international) | ✅ | ✅ | ✅ | — | — | — |
| igorrendulic/MimeEmailParser | ✅ | ✅ | ✅ | ✅ | — | — |
| bdolewski/SwiftEmailValidator | ✅ | — | — | — | — | — |
| jwelton/EmailValidator (NSDataDetector) | — | — | — | — | — | — |

✅ means the library declares support for the standard. The `Hardening`
column covers Unicode security mechanisms not strictly required by RFC 6531
but expected of contemporary validators. The capability mapping is encoded
in [`Capability.swift`](Benchmarks/Sources/EmailBench/Capability.swift) and
the matrix is regenerated every benchmark run.

### Results within declared scope

For each library, test cases whose required capability falls outside what
the library declares are excluded from both numerator and denominator. This
isolates each library's accuracy against the standards **it claims to
implement** — no penalty for not shipping RFC 6531 if it never claimed
RFC 6531.

| Library | In-scope passed | In-scope failed | Out-of-scope | In-scope accuracy | Modern accuracy⁴ |
|---|---:|---:|---:|---:|---:|
| SwiftEmailValidator (ASCII) | 223 | 0 | 20 | **100.0%** | 95.5% |
| SwiftEmailValidator (ASCII + RFC 2047) | 235 | 0 | 8 | **100.0%** | 96.7% |
| SwiftEmailValidator (Unicode) | 231 | 0 | 12 | **100.0%** | **100.0%** |
| evanrobertson/EmailValidator (ASCII) | 130 | 4 | 107 | 97.0% | 84.2% |
| evanrobertson/EmailValidator (international) | 136 | 3 | 99 | 97.8% | 63.4% |
| bdolewski/SwiftEmailValidator | 95 | 3 | 145 | 96.9% | 84.8% |
| igorrendulic/MimeEmailParser | 125 | 29 | 87 | 81.2% | 81.7% |
| jwelton/EmailValidator (NSDataDetector) | 0 | 0 | 243 | n/a³ | 56.8% |

³ NSDataDetector targets no documented RFC, so no cases are graded in-scope. Its `Modern accuracy` is a reference-mode comparison only.

⁴ `Modern accuracy` is `passed ÷ (passed + failed)` over the full 243-case corpus (skipped excluded). The `In-scope accuracy` column answers "given what this library claims to implement, how reliable is it?" while `Modern accuracy` answers "how much of a modern, RFC-current email validator does it actually cover?". A library can have a high in-scope score with a low modern score — that means it is solid within its lane, but the lane itself is narrow for current Internet mail.

### Inputs that crash competitor libraries

Recorded with the specific `fatalError` root cause, keyed by exact input:

| Library | Input | Root cause |
|---|---|---|
| evanrobertson/EmailValidator (ASCII) | `user@[0.0.0]` | indexes past end while scanning incomplete IPv4 literal |
| evanrobertson/EmailValidator (ASCII) | `user@[IPv6:]` | indexes past end on empty IPv6 literal |
| evanrobertson/EmailValidator (international) | `한.భారత్@x.한국` | `fatalError` on international local part (this is a **valid** RFC 6531 address) |
| evanrobertson/EmailValidator (international) | 16 × `𝄞` + `@site.com` | `fatalError` on 16 supplementary-plane scalars |
| evanrobertson/EmailValidator (international) | 30 × `𝄞` + `@site.com` | `fatalError` on 30 supplementary-plane scalars |
| evanrobertson/EmailValidator (international) | `user@[0.0.0]` | same IPv4-literal defect as ASCII mode |
| evanrobertson/EmailValidator (international) | `user@[IPv6:]` | same IPv6-literal defect as ASCII mode |
| igorrendulic/MimeEmailParser | `=?schtroomf?b?shackalaka?=` | `fatalError` decoding invalid base64 inside RFC 2047 encoded-word |
| igorrendulic/MimeEmailParser | `=?utf-8?B?7?=` | `fatalError` decoding truncated base64 inside RFC 2047 encoded-word |

SwiftEmailValidator, bdolewski, and jwelton-equivalent (NSDataDetector) did
not crash on any of the 243 inputs.

### Reverse check — running competitor test corpora through SwiftEmailValidator

Beyond our own 243-case corpus, the harness also runs each competitor's
**own test assertions** through our library to surface places where we
disagree with what they themselves claim is valid or invalid. Extract the
test corpora from each competitor's repo (evanrobertson: 96 cases,
bdolewski: 18, jwelton: 6, igorrendulic: 24 — inner mailbox addresses only,
since their suite parses `Name <mailbox>` envelopes we do not). Run them
through our three compatibility modes with a permissive `domainValidator`,
so the default IANA TLD + special-use blocklist doesn't mask pure syntax
disagreements. Reproduce with:

```bash
swift run -c release EmailBench --reverse
```

| Source | Total | Agreed | Disagreed |
|---|---:|---:|---:|
| evanrobertson | 96 | 93 | 3 |
| bdolewski | 18 | 18 | 0 |
| jwelton | 6 | 5 | 1 |
| igorrendulic | 24 | 24 | 0 |
| **Total** | **144** | **140** | **4** |

#### The 4 disagreements

| Source | Input | Competitor | Ours syntax (A / A+U / U) | Default validator (U) |
|---|---|---|---|---|
| evanrobertson | `another-invalid-ip@127.0.0.256` | invalid | true / true / true | **false** |
| evanrobertson | `invalid-ip@127.0.0.1.26` | invalid | true / true / true | **false** |
| evanrobertson | `unbracketed-IP@127.0.0.1` | invalid | true / true / true | **false** |
| jwelton | `test@example` | invalid | true / true / true | **false** |

* `Default validator (U)` is the shipped behaviour: our `.unicode` mode
  with the default `domainValidator` = `TLDDomainValidator.isPubliclyDeliverable`
  (IANA TLD list + RFC 6761 special-use blocklist). `example` is rejected
  because it has no TLD label; the IPv4-as-domain inputs are rejected
  because the rightmost label is numeric and not a TLD.
* When the `Default validator` column matches the competitor's expectation,
  the syntax-layer permissiveness is caught by the default policy layer and
  the shipped library agrees with the competitor.

#### Assessment

* **No genuine syntax gaps remaining.** The RFC 4291 §2.2 format-2 IPv6
  gap surfaced by this check in 1.4.0 (six uncompressed hex groups
  followed by a trailing IPv4 suffix, e.g. `aaaa:…:127.0.0.1`) was
  closed in 1.4.1.
* **4 policy-not-syntax differences** (`127.0.0.1.26`, `127.0.0.256`,
  `127.0.0.1`, `example` as domains). Purely numeric labels and single-label
  hostnames are syntactically valid per RFC 1035 / 5322, so our syntax
  layer accepts them. evanrobertson and jwelton fold the rejection into
  their syntax check. Our default `domainValidator` (`TLDDomainValidator`)
  catches all four as policy. Applications that want them to validate can
  already pass `domainValidator: { _ in true }`; applications that want the
  competitors' behaviour get it with the default.

### Caveat

These numbers reflect the 243 inputs in the SwiftEmailValidator corpus and
the reference-mode mapping described above. A different corpus, or a
different choice of reference mode per adapter, would produce different
scores. The full test data and the adapter definitions are in
[`Benchmarks/Sources/EmailBench/`](Benchmarks/Sources/EmailBench/) — run
the harness yourself to verify or experiment.

## Reference Documents

### Email syntax & internationalization

RFC822 - STANDARD FOR THE FORMAT OF ARPA INTERNET TEXT MESSAGES
https://datatracker.ietf.org/doc/html/rfc822

RFC2047 - MIME (Multipurpose Internet Mail Extensions) Part Three: Message Header Extensions for Non-ASCII Text
https://datatracker.ietf.org/doc/html/rfc2047

RFC5198 - Unicode Format for Network Interchange (NFC for transmission)
https://datatracker.ietf.org/doc/html/rfc5198

RFC5321 - Simple Mail Transfer Protocol
https://datatracker.ietf.org/doc/html/rfc5321

RFC5322 - Internet Message Format
https://datatracker.ietf.org/doc/html/rfc5322

RFC6531 - SMTP Extension for Internationalized Email
https://datatracker.ietf.org/doc/html/rfc6531

RFC6532 - Internationalized Email Headers (NFC normalization, §3.1)
https://datatracker.ietf.org/doc/html/rfc6532

UTS #39 - Unicode Security Mechanisms (Restriction Levels, §4 Confusables — via opt-in `SwiftEmailValidatorUTS39`)
https://www.unicode.org/reports/tr39/

UTS #46 - Unicode IDNA Compatibility Processing
https://www.unicode.org/reports/tr46/
  - Core: §4 step 1 dot-mapping (U+3002 / U+FF0E / U+FF61) in `TLDDomainValidator`.
  - Opt-in `SwiftEmailValidatorIDNA`: full §4 Map / NFC / Validate / ToASCII pipeline (Bidi + CONTEXTJ deferred).

RFC3492 - Punycode (used by `SwiftEmailValidatorIDNA` for ToASCII / ToUnicode)
https://datatracker.ietf.org/doc/html/rfc3492

### IETF Special-Use Domain Names (default `TLDDomainValidator` policy)

RFC3172 - Management Guidelines & Operational Requirements for the .arpa zone
https://datatracker.ietf.org/doc/html/rfc3172

RFC6761 - Special-Use Domain Names (.test, .example, .invalid, .localhost)
https://datatracker.ietf.org/doc/html/rfc6761

RFC6762 - Multicast DNS (.local)
https://datatracker.ietf.org/doc/html/rfc6762

RFC7686 - The ".onion" Special-Use Domain Name
https://datatracker.ietf.org/doc/html/rfc7686

RFC8375 - Special-Use Domain "home.arpa." (Homenet)
https://datatracker.ietf.org/doc/html/rfc8375

RFC9476 - The .alt Special-Use Top-Level Domain
https://datatracker.ietf.org/doc/html/rfc9476
