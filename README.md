![swift workflow](https://github.com/ekscrypto/SwiftEmailValidator/actions/workflows/swift.yml/badge.svg) [![codecov](https://codecov.io/gh/ekscrypto/SwiftEmailValidator/branch/main/graph/badge.svg?token=W9KO1BG8S0)](https://codecov.io/gh/ekscrypto/SwiftEmailValidator) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) ![Issues](https://img.shields.io/github/issues/ekscrypto/SwiftEmailValidator) ![Releases](https://img.shields.io/github/v/release/ekscrypto/SwiftEmailValidator)

# SwiftEmailValidator

A Swift implementation of an international email address syntax validator based on RFC822, RFC2047, RFC5321, RFC5322, and RFC6531. 
Since email addresses are local @ remote the validator also includes IPAddressSyntaxValidator and the SwiftPublicSuffixList library.

This Swift Package does not require an Internet connection at runtime and the only dependency is the [SwiftPublicSuffixList](https://github.com/ekscrypto/SwiftPublicSuffixList) library.

## Installation
### Swift Package Manager (SPM)

You can use The Swift Package Manager to install SwiftEmailValidator by adding it to your Package.swift file:

    import PackageDescription

    let package = Package(
        name: "MyApp",
        targets: [],
        dependencies: [
            .Package(url: "https://github.com/ekscrypto/SwiftEmailValidator.git", .upToNextMajor(from: "1.3.0"))
        ]
    )

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
