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
            .Package(url: "https://github.com/ekscrypto/SwiftEmailValidator.git", .upToNextMajor(from: "1.0.0"))
        ]
    )

## Public Suffix List

By default, domains are validated against the [Public Suffix List](https://publicsuffix.org) using the [SwiftPublicSuffixList](https://github.com/ekscrypto/SwiftPublicSuffixList) library.

### Notes:
* Due to the high number of entries in the Public Suffix list (>9k), the first validation may add 100ms to 900ms depending on the device you are using.  If this is unacceptable you can
 pre-load on a background thread PublicSuffixRulesRegistry.rules prior to using EmailSyntaxValidator.
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

## Reference Documents

RFC822 - STANDARD FOR THE FORMAT OF ARPA INTERNET TEXT MESSAGES
https://datatracker.ietf.org/doc/html/rfc822

RFC2047 - MIME (Multipurpose Internet Mail Extensions) Part Three: Message Header Extensions for Non-ASCII Text
https://datatracker.ietf.org/doc/html/rfc2047

RFC5321 - Simple Mail Transfer Protocol
https://datatracker.ietf.org/doc/html/rfc5321

RFC5322 - Internet Message Format
https://datatracker.ietf.org/doc/html/rfc5322

RFC6531 - SMTP Extension for Internationalized Email
https://datatracker.ietf.org/doc/html/rfc6531
