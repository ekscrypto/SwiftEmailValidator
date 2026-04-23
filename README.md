![swift workflow](https://github.com/ekscrypto/SwiftEmailValidator/actions/workflows/swift.yml/badge.svg) [![codecov](https://codecov.io/gh/ekscrypto/SwiftEmailValidator/branch/main/graph/badge.svg?token=W9KO1BG8S0)](https://codecov.io/gh/ekscrypto/SwiftEmailValidator) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) ![Issues](https://img.shields.io/github/issues/ekscrypto/SwiftEmailValidator) ![Releases](https://img.shields.io/github/v/release/ekscrypto/SwiftEmailValidator)

# SwiftEmailValidator

A Swift implementation of an international email address syntax validator based on RFC822, RFC2047, RFC5321, RFC5322, RFC6531, RFC6532 and UTS #39. 
Since email addresses are local @ remote the validator also includes IPAddressSyntaxValidator and the SwiftPublicSuffixList library.

This Swift Package does not require an Internet connection at runtime and the only dependency is the [SwiftPublicSuffixList](https://github.com/ekscrypto/SwiftPublicSuffixList) library.

The package ships **two library products**: `SwiftEmailValidator` (core RFC syntax validation, always-on) and `SwiftEmailValidatorUTS39` (opt-in Unicode Security Mechanisms — mixed-script detection, confusable skeletons, Identifier_Status filtering). The UTS #39 target carries ~280 KB of Unicode data and is imported separately so the core library stays slim. See [SwiftEmailValidatorUTS39](#swiftemailvalidatoruts39-unicode-security-mechanisms) below.

## Installation
### Swift Package Manager (SPM)

You can use The Swift Package Manager to install SwiftEmailValidator by adding it to your Package.swift file:

    import PackageDescription

    let package = Package(
        name: "MyApp",
        targets: [],
        dependencies: [
            .Package(url: "https://github.com/ekscrypto/SwiftEmailValidator.git", .upToNextMajor(from: "1.5.0"))
        ]
    )

Then depend on **one or both** library products from your target:

    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "SwiftEmailValidator", package: "SwiftEmailValidator"),
            // Opt in only if you need UTS #39 Unicode Security checks:
            .product(name: "SwiftEmailValidatorUTS39", package: "SwiftEmailValidator"),
        ])

## Performance Considerations

Due to the high number of entries in the Public Suffix list (>9k), the first email validation may add 100ms to 900ms depending on the device. To avoid this delay affecting user experience, you can pre-load the rules on a background thread soon after launching the app:

    import SwiftPublicSuffixList

    DispatchQueue.global(qos: .utility).async {
        _ = PublicSuffixRulesRegistry.rules
    }

## Public Suffix List

By default, domains are validated against the [Public Suffix List](https://publicsuffix.org) using the [SwiftPublicSuffixList](https://github.com/ekscrypto/SwiftPublicSuffixList) library.

### Notes:
* The [Public Suffix List](https://publicsuffix.org) is updated regularly. If your application is published regularly you may be fine by simply pulling the latest version of the SwiftPublicSuffixList library.  However it is recommended to have
your application retrieve the latest copy of the public suffix list on a somewhat regular basis.  Details on how to accomplish this are available in the [SwiftPublicSuffixList](https://github.com/ekscrypto/SwiftPublicSuffixList) library page.  You can then use the domainValidator parameter to specify the closure to use for the domain validation.  See "Using Custom SwiftPublicSuffixList Rules" below.
* You can bypass the Public Suffix List altogether and use your own custom Regex if desired. See "Bypassing SwiftPublicSuffixList" below.

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
    
#### Using Custom SwiftPublicSuffixList Rules
If you implement your own PublicSuffixList rules, or manage your own local copy of the rules as recommended:

    let customRules: [[String]] = [["com"]]
    if let mailboxInfo = EmailSyntaxValidator.mailbox(from: "santa.claus@northpole.com", domainValidator: { PublicSuffixList.isUnrestricted($0, rules: customRules)}) {
        // mailboxInfo.localPart == .dotAtom("santa.claus")
        // mailboxInfo.host == .domain("northpole.com")
    }

#### Bypassing SwiftPublicSuffixList
The EmailSyntaxValidator functions all accept a domainValidator closure, which by default uses the SwiftPublicSuffixList library.  This closure should return true if the domain should be considered valid, or false to be rejected.

    if let mailboxInfo = EmailSyntaxValidator.mailbox(from: "santa.claus@Ho Ho Ho North Pole", domainValidator: { _ in true }) {
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
    domainValidator: UTS39.domainValidator(policy),        // PSL + UTS #39 per label
    localPartValidator: UTS39.localPartValidator(policy))  // UTS #39 on the local part
```

`UTS39.domainValidator(_:base:)` accepts a custom base closure — by default
it wraps `PublicSuffixList.isUnrestricted(PublicSuffixList.ace($0))`:

```swift
let customRules: [[String]] = [["com"], ["net"]]
let domainValidator = UTS39.domainValidator(policy, base: {
    PublicSuffixList.isUnrestricted($0, rules: customRules)
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

The validator itself only checks syntax; whether a domain is accepted ultimately depends on the `domainValidator` closure. The default closure (`PublicSuffixList.isUnrestricted`) rejects single-label names because they have no registered public suffix. If you supply a permissive custom validator (`{ _ in true }`) single-label domains will be accepted. Make sure your validator enforces whatever hostname policy your application requires.

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

**Last run:** 2026-04-23 &middot; **Toolchain:** Swift 6.3.1, macOS 26.0 (arm64) &middot; **Harness:** [`Benchmarks/`](Benchmarks/)

The `Benchmarks/` SPM package runs the 195-case DemoApp corpus
(`DemoApp/EmailValidation/Data/TestData.swift`, mirrored verbatim into
`Benchmarks/Sources/EmailBench/TestData.swift`) through every competitor
library we could consume as an SPM dependency. The harness is kept in a
separate package so consumers of SwiftEmailValidator do not transitively
pull the competitor dependencies.

### Libraries tested

| Library | Tested revision | RFC coverage | PSL integration |
|---|---|---|---|
| [SwiftEmailValidator](https://github.com/ekscrypto/SwiftEmailValidator) (this package) | 1.4.1 | RFC 822 / 2047 / 5321 / 5322 / 6531 | ✅ (pluggable via `domainValidator:`) |
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

### Results (195-case corpus)

| Library | Passed | Failed | Skipped¹ | Accuracy² |
|---|---:|---:|---:|---:|
| SwiftEmailValidator (Unicode) | **195** | 0 | 0 | **100.0%** |
| SwiftEmailValidator (ASCII + RFC 2047) | 188 | 7 | 0 | 96.4% |
| SwiftEmailValidator (ASCII) | 185 | 10 | 0 | 94.9% |
| evanrobertson/EmailValidator (ASCII) | 177 | 16 | 2 | 91.7% |
| bdolewski/SwiftEmailValidator | 175 | 20 | 0 | 89.7% |
| igorrendulic/MimeEmailParser | 163 | 30 | 2 | 84.5% |
| evanrobertson/EmailValidator (international) | 150 | 40 | 5 | 78.9% |
| jwelton/EmailValidator (NSDataDetector) | 110 | 85 | 0 | 56.4% |

¹ Inputs that crash the library with Swift `fatalError`. Excluded from the
  accuracy denominator. Details below.
² Accuracy is computed over `Passed + Failed` only. Each adapter is graded
  against the ground truth defined for its reference mode (see Methodology).

### RFC 5322 scope: 10 corpus cases are not applicable to 5322-only libraries

Of the 195 cases, **10 require extensions beyond RFC 5322** to validate as
`expectedValid: true`:

* 6 × `validUnicode` (Korean, emoji, combining marks, mathematical bold — need RFC 6531)
* 3 × `validRFC2047` (B- and Q-encoded words — need RFC 2047)
* 1 × `validBoundary` (16 × U+1D11E MUSICAL SYMBOL G CLEF — needs RFC 6531)

The other 185 cases are fully applicable to any RFC 5322-only validator,
including every invalid-rejection test. Excluding the 10 N/A cases from
both numerator and denominator for the strictly 5322-only adapters yields:

| Library | Within-scope passed | Within-scope failures | Accuracy (5322 scope) |
|---|---:|---:|---:|
| evanrobertson/EmailValidator (ASCII) | 177 | 6 | **96.7%** (177 / 183) |
| bdolewski/SwiftEmailValidator | 175 | 10 | **94.6%** (175 / 185) |

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
not crash on any of the 195 inputs.

### Reverse check — running competitor test corpora through SwiftEmailValidator

Beyond our own 195-case corpus, the harness also runs each competitor's
**own test assertions** through our library to surface places where we
disagree with what they themselves claim is valid or invalid. Extract the
test corpora from each competitor's repo (evanrobertson: 96 cases,
bdolewski: 18, jwelton: 6, igorrendulic: 24 — inner mailbox addresses only,
since their suite parses `Name <mailbox>` envelopes we do not). Run them
through our three compatibility modes with a permissive `domainValidator`,
so PSL-based policy doesn't mask pure syntax disagreements. Reproduce with:

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

| Source | Input | Competitor | Ours syntax (A / A+U / U) | Default PSL (U) |
|---|---|---|---|---|
| evanrobertson | `another-invalid-ip@127.0.0.256` | invalid | true / true / true | **false** |
| evanrobertson | `invalid-ip@127.0.0.1.26` | invalid | true / true / true | **false** |
| evanrobertson | `unbracketed-IP@127.0.0.1` | invalid | true / true / true | **false** |
| jwelton | `test@example` | invalid | true / true / true | **false** |

* `Default PSL (U)` is the shipped behaviour: our `.unicode` mode with the
  default `domainValidator` = `PublicSuffixList.isUnrestricted`.
* When the `Default PSL` column matches the competitor's expectation, the
  syntax-layer permissiveness is caught by the policy layer and the shipped
  library agrees with the competitor.

#### Assessment

* **No genuine syntax gaps remaining.** The RFC 4291 §2.2 format-2 IPv6
  gap surfaced by this check in 1.4.0 (six uncompressed hex groups
  followed by a trailing IPv4 suffix, e.g. `aaaa:…:127.0.0.1`) was
  closed in 1.4.1.
* **4 policy-not-syntax differences** (`127.0.0.1.26`, `127.0.0.256`,
  `127.0.0.1`, `example` as domains). Purely numeric labels and single-label
  hostnames are syntactically valid per RFC 1035 / 5322, so our syntax
  layer accepts them. evanrobertson and jwelton fold the rejection into
  their syntax check. Our default `domainValidator` (`PublicSuffixList`)
  catches all four as policy. Applications that want them to validate can
  already pass `domainValidator: { _ in true }`; applications that want the
  competitors' behaviour get it with the default.

### Caveat

These numbers reflect the 195 inputs in the SwiftEmailValidator corpus and
the reference-mode mapping described above. A different corpus, or a
different choice of reference mode per adapter, would produce different
scores. The full test data and the adapter definitions are in
[`Benchmarks/Sources/EmailBench/`](Benchmarks/Sources/EmailBench/) — run
the harness yourself to verify or experiment.

## Reference Documents

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
