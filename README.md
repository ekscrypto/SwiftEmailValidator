![swift workflow](https://github.com/ekscrypto/SwiftEmailValidator/actions/workflows/swift.yml/badge.svg) [![codecov](https://codecov.io/gh/ekscrypto/SwiftEmailValidator/branch/main/graph/badge.svg?token=W9KO1BG8S0)](https://codecov.io/gh/ekscrypto/SwiftEmailValidator) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) ![Issues](https://img.shields.io/github/issues/ekscrypto/SwiftEmailValidator) ![Releases](https://img.shields.io/github/v/release/ekscrypto/SwiftEmailValidator)

# SwiftEmailValidator

A Swift implementation of an international email address syntax validator based on RFC822, RFC2047, RFC5321, RFC5322, and RFC6531. 
Since email addresses are local @ remote the validator also includes IPAddressSyntaxValidator and EmailHostSyntaxValidator classes. 
This Swift Package does not require an Internet connection at runtime and is entirely self contained.

Note: Due to the high number of entries in the Public Suffix list, you may want to pre-load on a background thread the
PublicSuffixRulesRegistry.rules prior to using EmailSyntaxValidator or EmailHostSyntaxValidator.

## Public Suffix List (regular updates required)

Domains are validated against the [Public Suffix List](https://publicsuffix.org). To update the built-in suffix list
(PublicSuffixRulesRegistry.swift) use the Utilities/update-suffix.swift script.

Public Suffix List last updated on 2022-01-22 10:48:00 EST

## Classes & Usage

### EmailSyntaxValidator

    if EmailSyntaxValidator.correctlyFormatted("email@example.com") {
        print("email@example.com respects Email syntax rules")
    }
    
    if EmailSyntaxValidator.correctlyFormatted("email@[127.0.0.1]", allowAddressLiteral: true) {
        print("email@[127.0.0.1] also respects since address literals are allowed")
    }
    
    if let mailboxInfo = EmailSyntaxValidator.mailbox(from: "email@[IPv6:fe80::1]", allowAddressLiteral: true) {
        // mailboxInfo.host == .addressLiteral("IPv6:fe80::1")
    }
    
    if let mailboxInfo = EmailSyntaxValidator.mailbox(from: "santa.claus@northpole.com") {
        // mailboxInfo.localPart == .dotAtom("santa.claus"
        // mailboxInfo.host == .domain("northpole.com")
    }

    if let mailboxInfo = EmailSyntaxValidator.mailbox(from: "=?utf-8?B?7ZWcQHgu7ZWc6rWt?=", compatibility: .asciiWithUnicodeExtension) {
        // mailboxInfo.localpart == .dotAtom("한")
        // mailboxInfo.host == .domain("x.한국")
    }
    
    if let mailboxInfo = EmailSyntaxValidator.mailbox(from: "\"santa.claus\"@northpole.com") {
        // mailboxInfo.localPart == .quotedString("santa.claus")
        // mailboxInfo.host == .domain("northpole.com"")
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


### EmailHostSyntaxValidator
Validates if the email's host name is following expected syntax rules and whether it is part of a known public suffix. Does NOT validate if the domain actually exists or even allowed by the registrar.

    if EmailHostSyntaxValidator.match("yahoo.com") {
        print("yahoo.com has valid email host syntax")
    }

### RFC2047Decoder
Allows to decode Unicode email addresses from SMTP headers

    print(RFC2047Decoder.decode("=?iso-8859-1?q?h=E9ro\@site.com?=")) 
    // héro@site.com

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

Public Suffix List
https://publicsuffix.org
