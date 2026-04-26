//
//  EmailSyntaxValidatorTests.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-21
//  Copyrights (C) 2022, Dave Poirier.  Distributed under MIT license
//
//  References:
//  * Test list of Valid and Invalid Email addresses https://gist.github.com/cjaoude/fd9910626629b53c4d25


import XCTest
@testable import SwiftEmailValidator

final class EmailSyntaxValidatorTests: XCTestCase {
    
    func baseMailboxLocalPartValidation(_ candidate: String) -> EmailSyntaxValidator.Mailbox.LocalPart? {
        EmailSyntaxValidator.mailbox(
            from: candidate,
            allowAddressLiteral: false,
            domainValidator: comOnlyDomainValidator)?.localPart
    }
    
    func testDotAtomLocalPart() {
        XCTAssertEqual(baseMailboxLocalPartValidation("user@site.com"), .dotAtom("user"))
        XCTAssertEqual(baseMailboxLocalPartValidation("first.last@site.com"), .dotAtom("first.last"))
        XCTAssertEqual(baseMailboxLocalPartValidation("first-@site.com"), .dotAtom("first-"))
        XCTAssertEqual(baseMailboxLocalPartValidation("!@site.com"), .dotAtom("!"))
        XCTAssertEqual(baseMailboxLocalPartValidation("#@site.com"), .dotAtom("#"))
        XCTAssertEqual(baseMailboxLocalPartValidation("$@site.com"), .dotAtom("$"))
        XCTAssertEqual(baseMailboxLocalPartValidation("%@site.com"), .dotAtom("%"))
        XCTAssertEqual(baseMailboxLocalPartValidation("&@site.com"), .dotAtom("&"))
        XCTAssertEqual(baseMailboxLocalPartValidation("'@site.com"), .dotAtom("'"))
        XCTAssertEqual(baseMailboxLocalPartValidation("*@site.com"), .dotAtom("*"))
        XCTAssertEqual(baseMailboxLocalPartValidation("+@site.com"), .dotAtom("+"))
        XCTAssertEqual(baseMailboxLocalPartValidation("-@site.com"), .dotAtom("-"))
        XCTAssertEqual(baseMailboxLocalPartValidation("/@site.com"), .dotAtom("/"))
        XCTAssertEqual(baseMailboxLocalPartValidation("=@site.com"), .dotAtom("="))
        XCTAssertEqual(baseMailboxLocalPartValidation("?@site.com"), .dotAtom("?"))
        XCTAssertEqual(baseMailboxLocalPartValidation("^@site.com"), .dotAtom("^"))
        XCTAssertEqual(baseMailboxLocalPartValidation("_@site.com"), .dotAtom("_"))
        XCTAssertEqual(baseMailboxLocalPartValidation("`@site.com"), .dotAtom("`"))
        XCTAssertEqual(baseMailboxLocalPartValidation("{@site.com"), .dotAtom("{"))
        XCTAssertEqual(baseMailboxLocalPartValidation("|@site.com"), .dotAtom("|"))
        XCTAssertEqual(baseMailboxLocalPartValidation("}@site.com"), .dotAtom("}"))
        XCTAssertEqual(baseMailboxLocalPartValidation("~@site.com"), .dotAtom("~"))
        XCTAssertEqual(baseMailboxLocalPartValidation("~.}.{._.^|.'+'.%!-.#&*.{u/=s3?r}`@site.com"), .dotAtom("~.}.{._.^|.'+'.%!-.#&*.{u/=s3?r}`"))
        XCTAssertNil(baseMailboxLocalPartValidation("user.@site.com"), "dot-Atom notation doesn't allow trailing dot")
        XCTAssertNil(baseMailboxLocalPartValidation(".user@site.com"), "dot-Atom notation doesn't allow leading dot")
        XCTAssertNil(baseMailboxLocalPartValidation("first..last@site.com"), "dot-Atom notation doesn't allow successive dots")
        XCTAssertNil(baseMailboxLocalPartValidation("\\user@site.com"), "Backslash not allowed in dot-Atom notation")
        XCTAssertNil(baseMailboxLocalPartValidation(":user@site.com"), "Colon not allowed in dot-Atom notation")
        XCTAssertNil(baseMailboxLocalPartValidation(":@site.com"), "Colon not allowed in dot-Atom notation")
        XCTAssertNil(baseMailboxLocalPartValidation(";@site.com"), "Semi-colon not allowed in dot-Atom notation")
        XCTAssertNil(baseMailboxLocalPartValidation("u\"@site.com"), "Double-quote not allowed in dot-Atom notation")
        XCTAssertNil(baseMailboxLocalPartValidation("user.\"name\"@site.com"), "Double-quote not allowed in dot-Atom notation")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"user\"@site.com"), .quotedString("user"), "Quoted form of a bare-word local part must parse as quotedString, not dotAtom")
    }
    
    func testSimpleQuotedLocalPart() {
        XCTAssertEqual(baseMailboxLocalPartValidation(#""email"@site.com"#), .quotedString(#"email"#))
    }
    
    func testQuotedTextLocalPart() {
        XCTAssertEqual(baseMailboxLocalPartValidation(#""Mickey Mouse"@disney.com"#), .quotedString("Mickey Mouse"), "Spaces are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation(#"""@site.com"#), .quotedString(""), "DQUOTE *QcontentSMTP DQUOTE implies empty quoted strings are allowed for local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\" \"@site.com"), .quotedString(" "), "Spaces are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"!\"@site.com"), .quotedString("!"), "! are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"#\"@site.com"), .quotedString("#"), "# are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"$\"@site.com"), .quotedString("$"), "$ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"%\"@site.com"), .quotedString("%"), "% are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"&\"@site.com"), .quotedString("&"), "& are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"'\"@site.com"), .quotedString("'"), "Single-quote are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"(\"@site.com"), .quotedString("("), "( are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\")\"@site.com"), .quotedString(")"), ") are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"*\"@site.com"), .quotedString("*"), "* are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"+\"@site.com"), .quotedString("+"), "+ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\",\"@site.com"), .quotedString(","), ", are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"-\"@site.com"), .quotedString("-"), "- are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\".\"@site.com"), .quotedString("."), ". are allowed without restriction in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"/\"@site.com"), .quotedString("/"), "/ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\":\"@site.com"), .quotedString(":"), ": are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\";\"@site.com"), .quotedString(";"), "; are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"<\"@site.com"), .quotedString("<"), "< are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"=\"@site.com"), .quotedString("="), "= are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\">\"@site.com"), .quotedString(">"), "> are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"?\"@site.com"), .quotedString("?"), "? are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"@\"@site.com"), .quotedString("@"), "@ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"[\"@site.com"), .quotedString("["), "[ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"]\"@site.com"), .quotedString("]"), "] are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"^\"@site.com"), .quotedString("^"), "^ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"_\"@site.com"), .quotedString("_"), "_ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"`\"@site.com"), .quotedString("`"), "` are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"{\"@site.com"), .quotedString("{"), "{ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"|\"@site.com"), .quotedString("|"), "| are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"}\"@site.com"), .quotedString("}"), "} are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"~\"@site.com"), .quotedString("~"), "~ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation(#""\\"@site.com"#), .quotedString("\\"), "Backslashes are allowed when escaped in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation(#""\t"@site.com"#), .quotedString("t"), "The next ascii (32-126) after a backslash is accepted as is so Blackslash-T isn't TAB but an actual t")
        XCTAssertEqual(baseMailboxLocalPartValidation(#""\""@site.com"#), .quotedString(#"""#), "Double-quotes are allowed when escaped in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation(#""email@notadomain.com"@site.com"#), .quotedString("email@notadomain.com"), "Since the @ is within the double quotes it is considered as the local part")
        XCTAssertNil(baseMailboxLocalPartValidation("\"\t\"@site.com"),"Tab is outside the 32-126 ascii range allowed in quoted text")
        XCTAssertNil(baseMailboxLocalPartValidation(#""\"@site.com"#),"The double-quote following the escape would have been escaped so the @site.com would still be part of the local part and no closing double-quotes would be found")
        XCTAssertNil(baseMailboxLocalPartValidation(#""email@notadomain.com""#), "Entire email address is within double-quotes so the whole thing would be considered the local part with no @ domain after the quotes this should be rejected")
    }
    
    func testEmailWithIPv4AddressLiteral() {
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "Santa.Claus@[127.0.0.1]", allowAddressLiteral: false))
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: "Santa.Claus@[127.0.0.1]", allowAddressLiteral: true)?.localPart, .dotAtom("Santa.Claus"), "When allowing address literals, email addresses should be valid if they specific @[<IPv4 Address>]")
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: "Santa.Claus@[127.0.0.1]", allowAddressLiteral: true)?.host, .addressLiteral("127.0.0.1"), "When allowing address literals, email addresses should be valid if they specific @[<IPv4 Address>]")
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted("Santa.Claus@[127.0.0.1]", allowAddressLiteral: true))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("Santa.Claus@[127.0.0.1]", allowAddressLiteral: false))
    }
    
    func testEmailWithIncorrectlyFormattedIPv4Literal() {
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("Santa.Claus@[127.0.0.1", allowAddressLiteral: true))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("Santa.Claus@127.0.0.1", allowAddressLiteral: true))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("Santa.Claus@[127.0.0.1].com", allowAddressLiteral: true))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("Santa.Claus@[127.0.0.1.]", allowAddressLiteral: true))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("Santa.Claus@[.127.0.0.1]", allowAddressLiteral: true))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("Santa.Claus@[127:0:0:1]", allowAddressLiteral: true))
    }
        
    func testEmailWithIPv6AddressLiteral() {
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "Santa.Claus@[IPv6:fe80::1]", allowAddressLiteral: false))
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: "Santa.Claus@[IPv6:fe80::1]", allowAddressLiteral: true)?.localPart, .dotAtom("Santa.Claus"), "When allowing address literals, email addresses should be valid if they specific @[IPv6:<IPv6 Address>]")
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: "Santa.Claus@[IPv6:fe80::1]", allowAddressLiteral: true)?.host, .addressLiteral("IPv6:fe80::1"), "When allowing address literals, email addresses should be valid if they specific @[IPv6:<IPv6 Address>]")
    }
    
    func testLocalPartMaximumLength() {
        let maxlocalPart = String(repeating: "x", count: 64)
        let testEmail = "\(maxlocalPart)@site.com"
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: testEmail)?.localPart, .dotAtom(maxlocalPart))
        let shouldBeInvalidEmail = "\(maxlocalPart)x@site.com"
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: shouldBeInvalidEmail))
    }
    
    func testAsciiRejectsUnicode() {
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "한@x.한국", compatibility: .ascii), "Unicode in email addresses should not be allowed in ASCII compatibility mode")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "\"한\"@x.한국", compatibility: .ascii), "Unicode in email addresses should not be allowed in ASCII compatibility mode")
    }

    func testAsciiRejectsUnicodeDomain() {
        // In .ascii mode the domain must also be ASCII-only (LDH labels or Punycode).
        // A Unicode U-label like 例え or 한국 must be rejected even when the local part is ASCII.
        let permissive: (String) -> Bool = { _ in true }
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user@例え.jp", compatibility: .ascii, domainValidator: permissive),
            "Unicode domain label must be rejected in .ascii mode"
        )
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user@x.한국", compatibility: .ascii, domainValidator: permissive),
            "Unicode TLD must be rejected in .ascii mode"
        )
        // Punycode ACE form is LDH and must be accepted
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user@xn--eckwd4c7c.jp", compatibility: .ascii, domainValidator: permissive),
            "Punycode ACE label must be accepted in .ascii mode (it is LDH)"
        )
        // Unicode domain must still be accepted in .unicode mode
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user@例え.jp", compatibility: .unicode, domainValidator: permissive),
            "Unicode domain label must be accepted in .unicode mode"
        )
    }
    
    func testUnicodeCompatibility() {
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: "한@x.한국", compatibility: .unicode)?.localPart, .dotAtom("한"), "Unicode email addresses should be allowed in Unicode compatibility")
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: "한.భారత్@x.한국", compatibility: .unicode)?.localPart, .dotAtom("한.భారత్"), "Unicode email addresses should be allowed in Unicode compatibility")
    }
    
    func testLocalPartWithQEncoding() {
        let testEmail = "=?iso-8859-1?q?\"Santa=20Claus\"@site.com?="
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: testEmail)?.localPart, .quotedString("Santa Claus"))
    }
    
    func testLocalPartWithBEncoding() {
        let testEmail = "=?utf-8?B?7ZWcQHgu7ZWc6rWt?="
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: testEmail)?.localPart, .dotAtom("한"))
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: testEmail)?.host, .domain("x.한국"))
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: testEmail, compatibility: .ascii))
    }
    
    func testMissingAt() {
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("santa.claus"))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("\"santa.claus\""))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("\"santa.claus\"northpole.com"))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("\"santa.claus@northpole.com"))
    }
    
    func testQuotedLocalPartWithInvalidEscapeSequence() {
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("\"test\\"))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted(#""santa\한"@northpole.com"#, compatibility: .ascii))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("\"santa\n\"@northpole.com", compatibility: .ascii))
    }
    
    func testQuotedLocalPartWithTooManyDquotes() {
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("\"Test\"\"@northpole.com"))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("\"Test\"@\"northpole.com"))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("\"Test\".hello\"@northpole.com"))
    }
    
    func testAsciiWithUnicodeExtension() {
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("한@x.한국", options: [], compatibility: .asciiWithUnicodeExtension), "Unicode characters not properly encoded should be rejected")
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("한@x.한국", options: [.autoEncodeToRfc2047], compatibility: .ascii), "Option .autoEncodeToRfc2047 should be ignored in pure ASCII compatibility mode")
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted("한@x.한국", options: [.autoEncodeToRfc2047], compatibility: .asciiWithUnicodeExtension), "Improperly encoded Unicode characters should be automatically RFC2047 encoded when .autoEncodeToRfc2047 option is specified")
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: "한@x.한국", options: [.autoEncodeToRfc2047], compatibility: .asciiWithUnicodeExtension)?.email, "=?utf-8?b?7ZWcQHgu7ZWc6rWt?=")
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: "한@x.한국", options: [.autoEncodeToRfc2047], compatibility: .asciiWithUnicodeExtension)?.localPart, .dotAtom("한"))
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: "한@x.한국", options: [.autoEncodeToRfc2047], compatibility: .asciiWithUnicodeExtension)?.host, .domain("x.한국"))
    }
    
    func testAutoEncodeToRfc2047Guards() {
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("=?utf-8?b?7ZWcQHgu7ZWc6rWt?=", options: [.autoEncodeToRfc2047], compatibility: .ascii))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("\nHello@this.com", options: [.autoEncodeToRfc2047], compatibility: .ascii))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("\nHello@this.com", options: [.autoEncodeToRfc2047], compatibility: .unicode))
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("1234567890123456789012345678901234567890123456789012345678901234567890@this.com", options: [.autoEncodeToRfc2047], compatibility: .asciiWithUnicodeExtension))
    }

    func testAutoEncodeToRfc2047WithEmailTooLongToEncode() {
        // RFC 2047 §2 caps an encoded-word at 76 characters.
        // =?utf-8?b?<base64>?= uses 12 chars of overhead, leaving 64 chars for base64 payload.
        // 64 base64 chars represent at most 48 bytes; a 12-emoji (@x.com) address is 54 UTF-8
        // bytes, producing an 84-char encoded word that exceeds the 76-char limit.
        // The validator must return nil rather than silently accepting or crashing.
        let permissive: (String) -> Bool = { _ in true }
        let twelveStarEmojis = String(repeating: "\u{1F31F}", count: 12)  // 12 × 4-byte UTF-8 = 48 bytes local part
        let longUnicodeEmail = "\(twelveStarEmojis)@x.com"                // 54 bytes total → 84-char encoded word
        XCTAssertEqual(longUnicodeEmail.utf8.count, 54)
        XCTAssertFalse(
            EmailSyntaxValidator.correctlyFormatted(
                longUnicodeEmail,
                options: [.autoEncodeToRfc2047],
                compatibility: .asciiWithUnicodeExtension,
                domainValidator: permissive
            ),
            "Email that encodes to an RFC2047 word exceeding 76 chars must be rejected"
        )
    }

    // MARK: - Phase 1: Local Part Boundary Tests

    func testLocalPartExactly63Characters() {
        let localPart63 = String(repeating: "x", count: 63)
        let testEmail = "\(localPart63)@site.com"
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: testEmail, domainValidator: comOnlyDomainValidator)?.localPart, .dotAtom(localPart63), "63-character local part should be valid (just under 64 limit)")
    }

    func testLocalPartExactlyOneCharacter() {
        XCTAssertEqual(baseMailboxLocalPartValidation("a@site.com"), .dotAtom("a"), "Single character local part should be valid")
        XCTAssertEqual(baseMailboxLocalPartValidation("1@site.com"), .dotAtom("1"), "Single digit local part should be valid")
    }

    func testLocalPartEmptyString() {
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "@site.com"), "Empty local part should be rejected")
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("@site.com"), "Empty local part should be rejected")
    }

    func testUnicodeLocalPartCharacterVsByteCount() {
        // Musical G clef U+1D11E is a 4-byte UTF-8 character
        // RFC 5321 §4.5.3.1.1: local part limit is 64 *octets* (bytes), not characters
        let fourByteChar = "\u{1D11E}" // 𝄞

        // 30 × 4-byte chars = 120 UTF-8 bytes > 64-byte limit → rejected
        let localPart30 = String(repeating: fourByteChar, count: 30)
        let testEmail30 = "\(localPart30)@site.com"
        let result30 = EmailSyntaxValidator.mailbox(from: testEmail30, compatibility: .unicode, domainValidator: comOnlyDomainValidator)
        XCTAssertNil(result30, "30 four-byte Unicode characters (120 bytes) should be rejected since RFC 5321 local part limit is 64 octets")

        // 16 × 4-byte chars = 64 UTF-8 bytes = exactly the limit → accepted
        let localPart16 = String(repeating: fourByteChar, count: 16)
        let testEmail16 = "\(localPart16)@site.com"
        let result16 = EmailSyntaxValidator.mailbox(from: testEmail16, compatibility: .unicode, domainValidator: comOnlyDomainValidator)
        XCTAssertNotNil(result16, "16 four-byte Unicode characters (64 bytes exactly) should be valid")
    }

    func testUnicodeLocalPartExceeds64Characters() {
        // 65 Unicode characters should be rejected
        let localPart65 = String(repeating: "한", count: 65)
        let testEmail = "\(localPart65)@site.com"
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: testEmail, compatibility: .unicode), "65-character Unicode local part should be rejected")
    }

    // MARK: - Phase 2: Unicode Edge Case Tests

    func testEmojiInLocalPart() {
        let emojiEmail = "user😀@site.com"
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: emojiEmail, compatibility: .ascii), "Emoji should be rejected in ASCII mode")
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: emojiEmail, compatibility: .unicode, domainValidator: comOnlyDomainValidator), "Emoji should be accepted in Unicode mode")
    }

    func testCombiningMarksInLocalPart() {
        // café with combining acute accent (e + combining acute)
        let combiningEmail = "cafe\u{0301}@site.com"
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: combiningEmail, compatibility: .ascii), "Combining marks should be rejected in ASCII mode")
        let result = EmailSyntaxValidator.mailbox(from: combiningEmail, compatibility: .unicode, domainValidator: comOnlyDomainValidator)
        XCTAssertNotNil(result, "Combining marks should be accepted in Unicode mode")
    }

    func testHighUnicodeRanges() {
        // Mathematical bold capital A (U+1D400) - beyond BMP
        let mathEmail = "\u{1D400}@site.com"
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: mathEmail, compatibility: .ascii), "High Unicode should be rejected in ASCII mode")
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: mathEmail, compatibility: .unicode, domainValidator: comOnlyDomainValidator), "High Unicode (beyond BMP) should be accepted in Unicode mode")
    }

    func testZeroWidthCharacters() {
        // Zero-width joiner U+200D is excluded as an invisible format character (spoofing prevention).
        // Allowing it would let "a\u{200D}b" and "ab" appear identical while being distinct addresses.
        let zwjEmail = "a\u{200D}b@site.com"
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: zwjEmail, compatibility: .unicode, domainValidator: comOnlyDomainValidator),
            "Zero-width joiner (U+200D) must be rejected to prevent email address spoofing"
        )
    }

    func testBidirectionalOverrideCharacters() {
        // Bidirectional override characters (U+202A-U+202E) are excluded per security best practices
        // These can be used for text spoofing attacks (e.g., displaying filenames in reverse)
        let rtlOverride = "test\u{202E}@site.com"  // Right-to-left override
        let ltrOverride = "test\u{202D}@site.com"  // Left-to-right override
        let ltrMark = "test\u{200E}@site.com"      // Left-to-right mark

        XCTAssertNil(EmailSyntaxValidator.mailbox(from: rtlOverride, compatibility: .ascii), "Bidirectional override should be rejected in ASCII mode")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: rtlOverride, compatibility: .unicode), "Bidirectional overrides should be rejected for security")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: ltrOverride, compatibility: .unicode), "Bidirectional overrides should be rejected for security")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: ltrMark, compatibility: .unicode), "Bidirectional marks should be rejected for security")
    }

    func testC1ControlCharactersRejected() {
        // C1 control characters (U+0080-U+009F) should be rejected per RFC 5198 Section 2
        // "Control characters (U+0000-U+001F, U+007F-U+009F) should be avoided"
        let c1Start = "test\u{0080}@site.com"  // First C1 control character
        let c1Mid = "test\u{0090}@site.com"    // Middle of C1 range
        let c1End = "test\u{009F}@site.com"    // Last C1 control character

        XCTAssertNil(EmailSyntaxValidator.mailbox(from: c1Start, compatibility: .unicode), "C1 control U+0080 should be rejected per RFC 5198")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: c1Mid, compatibility: .unicode), "C1 control U+0090 should be rejected per RFC 5198")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: c1End, compatibility: .unicode), "C1 control U+009F should be rejected per RFC 5198")
    }

    // MARK: - Phase 2: Combined Feature Tests

    func testRFC2047EncodedWithIPv4AddressLiteral() {
        // Encode "user@[127.0.0.1]" with RFC2047
        let original = "user@[127.0.0.1]"
        guard let encoded = RFC2047Coder.encode(original) else {
            XCTFail("Failed to encode test email")
            return
        }
        let result = EmailSyntaxValidator.mailbox(from: encoded, allowAddressLiteral: true)
        XCTAssertNotNil(result, "RFC2047 encoded email with IPv4 address literal should be valid")
        XCTAssertEqual(result?.host, .addressLiteral("127.0.0.1"))
    }

    func testRFC2047EncodedWithIPv6AddressLiteral() {
        // Encode "user@[IPv6:fe80::1]" with RFC2047
        let original = "user@[IPv6:fe80::1]"
        guard let encoded = RFC2047Coder.encode(original) else {
            XCTFail("Failed to encode test email")
            return
        }
        let result = EmailSyntaxValidator.mailbox(from: encoded, allowAddressLiteral: true)
        XCTAssertNotNil(result, "RFC2047 encoded email with IPv6 address literal should be valid")
        XCTAssertEqual(result?.host, .addressLiteral("IPv6:fe80::1"))
    }

    func testQuotedStringWithMultipleAtSymbols() {
        // Multiple @ inside quoted string should be valid
        let multiAtEmail = #""user@fake@also"@site.com"#
        let result = EmailSyntaxValidator.mailbox(from: multiAtEmail, domainValidator: comOnlyDomainValidator)
        XCTAssertEqual(result?.localPart, .quotedString("user@fake@also"), "Multiple @ symbols inside quoted string should be valid")
        XCTAssertEqual(result?.host, .domain("site.com"))
    }

    func testQuotedStringWithRFC2047Decoding() {
        // RFC2047 encode a quoted string email: "Santa Claus"@site.com
        let rfc2047Encoded = "=?iso-8859-1?q?\"Santa=20Claus\"@site.com?="
        let result = EmailSyntaxValidator.mailbox(from: rfc2047Encoded, domainValidator: comOnlyDomainValidator)
        XCTAssertEqual(result?.localPart, .quotedString("Santa Claus"), "RFC2047 decoded quoted string should be valid")
    }

    func testAutoEncodeToRfc2047WithAddressLiteral() {
        // Test that autoEncode option works with address literals
        let unicodeEmail = "한@[127.0.0.1]"
        let result = EmailSyntaxValidator.mailbox(
            from: unicodeEmail,
            options: [.autoEncodeToRfc2047],
            compatibility: .asciiWithUnicodeExtension,
            allowAddressLiteral: true
        )
        XCTAssertNotNil(result, "Auto-encode with address literal should work")
        if let mailbox = result {
            XCTAssertTrue(mailbox.email.hasPrefix("=?utf-8?b?"), "Email should be RFC2047 encoded")
        }
    }

    // MARK: - Phase 2: Custom Domain Validator Tests

    func testCustomDomainValidatorAcceptsAnyDomain() {
        let permissiveValidator: (String) -> Bool = { _ in true }
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: "user@anything.xyz", domainValidator: permissiveValidator))
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: "user@random.domain", domainValidator: permissiveValidator))
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: "user@test.notreal", domainValidator: permissiveValidator))
    }

    func testCustomDomainValidatorRejectsAllDomains() {
        let restrictiveValidator: (String) -> Bool = { _ in false }
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@example.com", domainValidator: restrictiveValidator), "Restrictive validator should reject all domains")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@google.com", domainValidator: restrictiveValidator), "Restrictive validator should reject all domains")
    }

    func testCustomDomainValidatorWithSpecificTLDs() {
        let comOnlyValidator: (String) -> Bool = { domain in
            domain.hasSuffix(".com")
        }
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: "user@example.com", domainValidator: comOnlyValidator), ".com domain should be accepted")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@example.org", domainValidator: comOnlyValidator), ".org domain should be rejected by .com-only validator")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@example.net", domainValidator: comOnlyValidator), ".net domain should be rejected by .com-only validator")
    }

    func testCustomDomainValidatorReceivesCorrectDomain() {
        var capturedDomain: String?
        let capturingValidator: (String) -> Bool = { domain in
            capturedDomain = domain
            return true
        }
        _ = EmailSyntaxValidator.mailbox(from: "user@captured.domain.com", domainValidator: capturingValidator)
        XCTAssertEqual(capturedDomain, "captured.domain.com", "Validator should receive exact domain after @")
    }

    func testCustomDomainValidatorWithUnicodeDomain() {
        var capturedDomain: String?
        let capturingValidator: (String) -> Bool = { domain in
            capturedDomain = domain
            return true
        }
        _ = EmailSyntaxValidator.mailbox(from: "user@例え.jp", compatibility: .unicode, domainValidator: capturingValidator)
        XCTAssertEqual(capturedDomain, "例え.jp", "Validator should receive Unicode domain")
    }

    // MARK: - Phase 3: Dot/Special Character Sequence Tests

    func testMultipleDotsInVariousPositions() {
        let validMultiDot = [
            "a.b.c@site.com",
            "a.b.c.d.e@site.com",
            "first.middle.last@site.com"
        ]
        for email in validMultiDot {
            XCTAssertNotNil(baseMailboxLocalPartValidation(email), "\(email) should be valid with multiple dots")
        }
    }

    func testSingleCharactersBetweenDots() {
        XCTAssertEqual(baseMailboxLocalPartValidation("a.b.c@site.com"), .dotAtom("a.b.c"), "Single characters between dots should be valid")
        XCTAssertEqual(baseMailboxLocalPartValidation("1.2.3@site.com"), .dotAtom("1.2.3"), "Single digits between dots should be valid")
    }

    func testMaxConsecutiveSpecialCharacters() {
        // Multiple consecutive special characters should be valid in dot-atom
        XCTAssertEqual(baseMailboxLocalPartValidation("!!@site.com"), .dotAtom("!!"), "Consecutive ! should be valid")
        XCTAssertEqual(baseMailboxLocalPartValidation("##$$@site.com"), .dotAtom("##$$"), "Consecutive # and $ should be valid")
        XCTAssertEqual(baseMailboxLocalPartValidation("a+++b@site.com"), .dotAtom("a+++b"), "Consecutive + should be valid")
    }

    func testSpecialCharactersAtBoundaries() {
        // Special characters at start and end of local part
        XCTAssertEqual(baseMailboxLocalPartValidation("!user@site.com"), .dotAtom("!user"), "! at start should be valid")
        XCTAssertEqual(baseMailboxLocalPartValidation("user!@site.com"), .dotAtom("user!"), "! at end should be valid")
        XCTAssertEqual(baseMailboxLocalPartValidation("+user+@site.com"), .dotAtom("+user+"), "+ at both ends should be valid")
    }

    // MARK: - Phase 3: Performance/Stress Tests

    func testExtremelyLongLocalPart() {
        let longLocalPart = String(repeating: "x", count: 1000)
        let testEmail = "\(longLocalPart)@site.com"
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: testEmail), "1000-character local part should be rejected (exceeds 64 limit)")
    }

    func testExtremelyLongDomain() {
        let permissive: (String) -> Bool = { _ in true }

        // RFC 1035: a single label exceeding 63 chars should be rejected
        let longLabelDomain = String(repeating: "x", count: 64) + ".com"
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@\(longLabelDomain)", domainValidator: permissive),
                     "Domain with a label longer than 63 chars should be rejected")

        // Valid labels (≤63 chars each) but total domain > 253 chars → rejected
        // 63+1+63+1+63+1+63+1+3 = 259 chars > 253
        let longTotalDomain = String(repeating: "a", count: 63) + "."
            + String(repeating: "b", count: 63) + "."
            + String(repeating: "c", count: 63) + "."
            + String(repeating: "d", count: 63) + ".com"
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@\(longTotalDomain)", domainValidator: permissive),
                     "Domain with total length > 253 chars should be rejected")

        // Valid labels and total < 253 chars → accepted with permissive validator
        // 63+1+63+1+3 = 131 chars < 253
        let validLongDomain = String(repeating: "a", count: 63) + "." + String(repeating: "b", count: 63) + ".com"
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: "user@\(validLongDomain)", domainValidator: permissive),
                        "Domain with valid-length labels totaling < 253 chars should be accepted with permissive validator")
    }

    func testDomainLabelUnicodeByteLengthEnforced() {
        // RFC 1035 §2.3.4: each label must be ≤63 *octets*.
        // A label composed of 32 two-byte characters is 32 characters (≤63) but 64 UTF-8 bytes (>63).
        // It must be rejected even though the character count is within the old (wrong) limit.
        let permissive: (String) -> Bool = { _ in true }

        // "ñ" is U+00F1, 2 UTF-8 bytes. 32 × "ñ" = 32 chars / 64 bytes → label too long in octets.
        let twoByteChar = "ñ"
        XCTAssertEqual(twoByteChar.utf8.count, 2)
        let label64Bytes = String(repeating: twoByteChar, count: 32) // 32 chars, 64 bytes
        XCTAssertEqual(label64Bytes.count, 32)
        XCTAssertEqual(label64Bytes.utf8.count, 64)
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@\(label64Bytes).com", compatibility: .unicode, domainValidator: permissive),
                     "Domain label with 64 UTF-8 bytes (32 two-byte chars) must be rejected per RFC 1035")

        // 31 × "ñ" = 31 chars / 62 bytes → should be accepted (within both limits).
        let label62Bytes = String(repeating: twoByteChar, count: 31) // 31 chars, 62 bytes
        XCTAssertEqual(label62Bytes.utf8.count, 62)
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: "user@\(label62Bytes).com", compatibility: .unicode, domainValidator: permissive),
                        "Domain label with 62 UTF-8 bytes should be accepted")
    }

    func testTotalDomainUnicodeByteLengthEnforced() {
        // RFC 1035 §2.3.4: total domain must be ≤253 *octets*.
        // Build a domain whose character count is ≤253 but whose UTF-8 byte count exceeds 253.
        // Each label: 31 × "ñ" (31 chars, 62 bytes); three labels + dots = 62+1+62+1+62 = 188 chars / bytes.
        // Add a fourth label of 30 two-byte chars: 188+1+60 = 249 chars / 188+1+60 = 249 bytes — ok.
        // Then push it over 253 bytes without going over 253 chars by using more two-byte chars.
        let permissive: (String) -> Bool = { _ in true }
        let twoByteChar = "ñ"

        // Construct a domain that is 127 chars but 254 bytes.
        // Three labels of 31 "ñ" each = 31*3 + 2 dots = 95 chars / 62*3+2 = 188 bytes.
        // Add a 4th label of 33 "ñ" = 33 chars / 66 bytes → total 129 chars / 255 bytes → reject.
        let label31 = String(repeating: twoByteChar, count: 31) // 62 bytes, 31 chars
        let label33 = String(repeating: twoByteChar, count: 33) // 66 bytes, 33 chars
        let longByteDomain = "\(label31).\(label31).\(label31).\(label33)"
        XCTAssertLessThanOrEqual(longByteDomain.count, 253, "character count must be ≤253 to test the byte-count path")
        XCTAssertGreaterThan(longByteDomain.utf8.count, 253, "byte count must exceed 253 to exercise the fix")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "u@\(longByteDomain)", compatibility: .unicode, domainValidator: permissive),
                     "Domain exceeding 253 UTF-8 bytes must be rejected even if character count ≤253")
    }

    func testVeryLongRFC2047EncodedString() {
        // RFC2047 has 76-character limit
        // Create a string that when encoded exceeds 76 chars
        let longString = String(repeating: "한", count: 20) // Will exceed 76 chars when encoded
        let encoded = RFC2047Coder.encode(longString)
        // If encoded result exceeds 76 chars, decode should return nil
        if let enc = encoded, enc.count > 76 {
            XCTAssertNil(RFC2047Coder.decode(enc), "RFC2047 encoded string over 76 chars should fail decoding")
        }
    }

    func testTotalEmailLengthLimit() {
        let permissive: (String) -> Bool = { _ in true }

        // ASCII: local=64 bytes, @=1 byte, domain=189 bytes (63+1+63+1+61) → total 254 bytes → valid
        let localPart64 = String(repeating: "x", count: 64)
        let domain189 = String(repeating: "a", count: 63) + "." + String(repeating: "b", count: 63) + "." + String(repeating: "c", count: 61)
        let email254 = "\(localPart64)@\(domain189)"
        XCTAssertEqual(email254.utf8.count, 254)
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: email254, compatibility: .ascii, domainValidator: permissive),
                        "254-byte email should be valid")

        // ASCII: same but one extra byte in domain → total 255 bytes → rejected
        let domain190 = domain189 + "x"
        let email255 = "\(localPart64)@\(domain190)"
        XCTAssertEqual(email255.utf8.count, 255)
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: email255, compatibility: .ascii, domainValidator: permissive),
                     "255-byte email should be rejected")

        // Unicode: local part uses 3-byte chars; multi-byte total tips over 254 bytes
        // 21 × "三" (3 bytes each) = 63 bytes; domain 63+1+63+1+62=190 bytes → total 254 bytes → valid
        let unicodeLocal63 = String(repeating: "三", count: 21)
        XCTAssertEqual(unicodeLocal63.utf8.count, 63)
        let unicodeDomain190 = String(repeating: "a", count: 63) + "." + String(repeating: "b", count: 63) + "." + String(repeating: "c", count: 62)
        XCTAssertEqual(unicodeDomain190.utf8.count, 190)
        let unicodeEmail254 = "\(unicodeLocal63)@\(unicodeDomain190)"
        XCTAssertEqual(unicodeEmail254.utf8.count, 254)
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: unicodeEmail254, compatibility: .unicode, domainValidator: permissive),
                        "Unicode 254-byte email should be valid")

        // Unicode: same but domain has one extra byte → total 255 bytes → rejected
        let unicodeDomain191 = String(repeating: "a", count: 63) + "." + String(repeating: "b", count: 63) + "." + String(repeating: "c", count: 63)
        XCTAssertEqual(unicodeDomain191.utf8.count, 191)
        let unicodeEmail255 = "\(unicodeLocal63)@\(unicodeDomain191)"
        XCTAssertEqual(unicodeEmail255.utf8.count, 255)
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: unicodeEmail255, compatibility: .unicode, domainValidator: permissive),
                     "Unicode 255-byte email should be rejected")
    }

    func testBmpPrivateUseAreaRejected() {
        // BMP Private Use Area characters (U+E000–U+F8FF) must be rejected in Unicode local parts
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user\u{E000}@site.com", compatibility: .unicode),
                     "BMP PUA U+E000 should be rejected in Unicode local part")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user\u{F8FF}@site.com", compatibility: .unicode),
                     "BMP PUA U+F8FF should be rejected in Unicode local part")
    }

    func testManyUnicodeCharactersInLocalPart() {
        // 64 diverse Unicode characters from different scripts
        let diverse = "한中あαбעعहবதతకಕමෆไᎠ" // Various scripts
        let localPart = String(diverse.prefix(60)) // Stay under 64
        let testEmail = "\(localPart)@site.com"
        let result = EmailSyntaxValidator.mailbox(from: testEmail, compatibility: .unicode, domainValidator: comOnlyDomainValidator)
        XCTAssertNotNil(result, "Diverse Unicode characters should be valid in Unicode mode")
    }

    // MARK: - RFC Compliance Fixes

    func testQuotedStringLocalPartLengthLimit() {
        let permissive: (String) -> Bool = { _ in true }

        // " + 62 a's + " = 64 UTF-8 bytes → at limit, accepted
        let exactly64 = "\"" + String(repeating: "a", count: 62) + "\""
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: "\(exactly64)@site.com", domainValidator: permissive),
                        "Quoted-string local part of exactly 64 UTF-8 bytes should be accepted")

        // " + 63 a's + " = 65 UTF-8 bytes → over limit, rejected
        let over64 = "\"" + String(repeating: "a", count: 63) + "\""
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "\(over64)@site.com", domainValidator: permissive),
                     "Quoted-string local part exceeding 64 UTF-8 bytes should be rejected")

        // Multi-byte Unicode: " + 16 × 4-byte chars + " = 66 UTF-8 bytes → rejected
        let multiByteOver = "\"" + String(repeating: "\u{1D11E}", count: 16) + "\""
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "\(multiByteOver)@site.com", compatibility: .unicode, domainValidator: permissive),
                     "Quoted-string with multi-byte chars exceeding 64 bytes should be rejected")
    }

    func testEmptyHostRejectedWithPermissiveValidator() {
        let permissive: (String) -> Bool = { _ in true }
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@", domainValidator: permissive),
                     "Empty host must be rejected regardless of domain validator")
    }

    func testDoubleAtSignRejectedWithPermissiveValidator() {
        let permissive: (String) -> Bool = { _ in true }
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@@example.com", domainValidator: permissive),
                     "Double @ must be rejected regardless of domain validator")
    }

    func testEmptyDomainLabelRejectedWithPermissiveValidator() {
        let permissive: (String) -> Bool = { _ in true }
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@example..com", domainValidator: permissive),
                     "Consecutive dots (empty label) must be rejected regardless of domain validator")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@.example.com", domainValidator: permissive),
                     "Leading dot in domain must be rejected regardless of domain validator")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@example.com.", domainValidator: permissive),
                     "Trailing dot in domain must be rejected regardless of domain validator")
    }

    func testInvalidDomainLabelCharactersRejectedWithPermissiveValidator() {
        let permissive: (String) -> Bool = { _ in true }
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@exam ple.com", domainValidator: permissive),
                     "Space in domain label must be rejected regardless of domain validator")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@exam@ple.com", domainValidator: permissive),
                     "@ in domain label must be rejected regardless of domain validator")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@exam#ple.com", domainValidator: permissive),
                     "# in domain label must be rejected regardless of domain validator")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@exam[ple.com", domainValidator: permissive),
                     "[ in domain label must be rejected regardless of domain validator")
    }

    func testLeadingTrailingHyphenInDomainLabelRejectedWithPermissiveValidator() {
        let permissive: (String) -> Bool = { _ in true }
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@-example.com", domainValidator: permissive),
                     "Leading hyphen in domain label must be rejected regardless of domain validator")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@example-.com", domainValidator: permissive),
                     "Trailing hyphen in domain label must be rejected regardless of domain validator")
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: "user@ex-ample.com", domainValidator: permissive),
                        "Hyphen within a domain label should remain valid")
    }

    // MARK: - S1: Invisible / zero-width character exclusions

    func testInvisibleCharactersRejectedInLocalPart() {
        // Invisible and zero-width format characters must be rejected in Unicode local parts.
        // Accepting them lets an attacker create addresses that look identical to a legitimate
        // one but are treated as distinct (account duplication / spoofing).
        let permissive: (String) -> Bool = { _ in true }
        let invisibleChars: [(String, String)] = [
            ("\u{00AD}", "U+00AD Soft Hyphen"),
            ("\u{200B}", "U+200B Zero Width Space"),
            ("\u{200C}", "U+200C Zero Width Non-Joiner"),
            ("\u{200D}", "U+200D Zero Width Joiner"),
            ("\u{2060}", "U+2060 Word Joiner"),
            ("\u{2061}", "U+2061 Function Application (invisible math)"),
            ("\u{2062}", "U+2062 Invisible Times"),
            ("\u{2063}", "U+2063 Invisible Separator"),
            ("\u{2064}", "U+2064 Invisible Plus"),
            ("\u{FEFF}", "U+FEFF BOM / Zero Width No-Break Space"),
        ]
        for (char, name) in invisibleChars {
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com", compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part (spoofing prevention)"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com", compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part (spoofing prevention)"
            )
        }
    }

    func testVariationSelectorsRejectedInLocalPart() {
        // Variation Selectors (U+FE00-U+FE0F) and Variation Selectors Supplement (U+E0100-U+E01EF)
        // are invisible combining characters. They produce no glyph and render identically to their
        // base character in all common renderers, making "user\u{FE01}" visually indistinguishable
        // from "user" — the same spoofing risk as ZWJ/ZWNJ, which are already blocked.
        let permissive: (String) -> Bool = { _ in true }

        // BMP Variation Selectors (U+FE00-U+FE0F) — spot-check first, middle, last
        let bmpVariationSelectors: [(String, String)] = [
            ("\u{FE00}", "U+FE00 Variation Selector-1"),
            ("\u{FE08}", "U+FE08 Variation Selector-9"),
            ("\u{FE0F}", "U+FE0F Variation Selector-16"),
        ]
        for (char, name) in bmpVariationSelectors {
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com", compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part (spoofing prevention)"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com", compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part (spoofing prevention)"
            )
        }

        // Variation Selectors Supplement (U+E0100-U+E01EF) — spot-check first, middle, last
        let supplementVariationSelectors: [(Unicode.Scalar, String)] = [
            (Unicode.Scalar(0xE0100)!, "U+E0100 Variation Selector-17"),
            (Unicode.Scalar(0xE0140)!, "U+E0140 Variation Selector-81"),
            (Unicode.Scalar(0xE01EF)!, "U+E01EF Variation Selector-256"),
        ]
        for (scalar, name) in supplementVariationSelectors {
            let char = String(scalar)
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com", compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part (spoofing prevention)"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com", compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part (spoofing prevention)"
            )
        }
    }

    func testLineSeparatorCharactersRejectedInLocalPart() {
        // U+2028 (Line Separator) and U+2029 (Paragraph Separator) carry line-break
        // semantics in some runtimes and are not explicitly permitted by RFC 6531/6532.
        // They must be rejected to prevent unexpected behaviour in downstream relay parsers.
        let permissive: (String) -> Bool = { _ in true }
        let lineSepChars: [(String, String)] = [
            ("\u{2028}", "U+2028 Line Separator"),
            ("\u{2029}", "U+2029 Paragraph Separator"),
        ]
        for (char, name) in lineSepChars {
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part"
            )
        }
        // Confirm neighbours are unaffected
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user\u{2027}@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "U+2027 (Hyphenation Point) just below the range should still be accepted"
        )
    }

    // MARK: - S2: Unicode Tags block exclusion

    func testUnicodeTagsBlockRejectedInLocalPart() {
        // The Unicode Tags block (U+E0000-U+E007F) contains deprecated characters originally
        // intended for invisible language tagging. They produce no visible glyph and can be
        // used to embed invisible payload in what appears to be a normal email address.
        let permissive: (String) -> Bool = { _ in true }
        let tagChars: [(String, String)] = [
            ("\u{E0001}", "U+E0001 Language Tag"),
            ("\u{E0041}", "U+E0041 Tag Latin Capital Letter A"),
            ("\u{E0061}", "U+E0061 Tag Latin Small Letter A"),
            ("\u{E007F}", "U+E007F Tag Delete (last char of Tags block)"),
        ]
        for (char, name) in tagChars {
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com", compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part (invisible tag character)"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com", compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part (invisible tag character)"
            )
        }
        // Confirm characters just outside the Tags block remain accepted
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user\u{1F600}@site.com", compatibility: .unicode, domainValidator: permissive),
            "U+1F600 (emoji, SMP) just below Tags block should still be accepted"
        )
    }

    // MARK: - S3: Control characters, source routes, bare IPv4, bidi/deprecated chars, unassigned SSP

    func testControlCharsRejectedInLocalPart() {
        // C0 controls (U+0000-U+001F) and DEL (U+007F) are absent from atextCharacterSet
        // and qtextSMTPCharacterSet, so they must be rejected in both dot-atom and
        // quoted-string local parts.
        let permissive: (String) -> Bool = { _ in true }
        let controlChars: [(String, String)] = [
            ("\u{0001}", "U+0001 SOH (first C0 control)"),
            ("\u{001F}", "U+001F US (last C0 control)"),
            ("\u{007F}", "U+007F DEL"),
        ]
        for (char, name) in controlChars {
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part"
            )
        }
    }

    func testSourceRoutesRejected() {
        // RFC 5321 deprecated source routes (@relay:user@domain). The leading '@' produces an
        // empty string before the first '@', failing the dotAtom count > 0 check.
        let permissive: (String) -> Bool = { _ in true }
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "@relay.host,@relay2.host:user@domain.com",
                domainValidator: permissive),
            "Source-route format must be rejected (empty local part before first @)"
        )
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "@relay.host:user@domain.com",
                domainValidator: permissive),
            "Single-relay source-route must also be rejected"
        )
    }

    func testBareIPv4AcceptedAsDomainWithPermissiveValidator() {
        // Without brackets, 192.168.1.1 is syntactically valid as four LDH labels composed
        // entirely of digits. A permissive domain validator accepts it; the default PSL-based
        // validator rejects it. Use allowAddressLiteral:true with [192.168.1.1] for IP literals.
        let permissive: (String) -> Bool = { _ in true }
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user@192.168.1.1", domainValidator: permissive),
            "Bare IPv4 (no brackets) passes as an LDH domain with a permissive domain validator"
        )
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user@192.168.1.1"),
            "Bare IPv4 (no brackets) must be rejected by the default PSL-based domain validator"
        )
    }

    func testBidiMarksRejectedInQuotedStringLocalPart() {
        // Bidirectional formatting marks (U+200E-U+200F, U+202A-U+202E, U+2066-U+2069) are
        // removed from qtextUnicodeSMTPCharacterSet via .subtracting(bidiFormattingChars).
        // The per-scalar allSatisfy check (Bug 2 fix) ensures every scalar in a grapheme
        // cluster is validated, not just the first one.
        let permissive: (String) -> Bool = { _ in true }
        let bidiChars: [(String, String)] = [
            ("\u{200E}", "U+200E Left-to-Right Mark"),
            ("\u{200F}", "U+200F Right-to-Left Mark"),
            ("\u{202A}", "U+202A Left-to-Right Embedding"),
            ("\u{202D}", "U+202D Left-to-Right Override"),
            ("\u{202E}", "U+202E Right-to-Left Override"),
            ("\u{2066}", "U+2066 Left-to-Right Isolate"),
            ("\u{2069}", "U+2069 Pop Directional Isolate"),
        ]
        for (char, name) in bidiChars {
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part"
            )
            // Also verify rejection in dot-atom (covered by atextUnicodeCharacterSet exclusion)
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part"
            )
        }
    }

    func testDeprecatedFormatCharsRejectedInLocalPart() {
        // Deprecated Unicode format characters (U+206A-U+206F) are removed from both
        // atextUnicodeCharacterSet and qtextUnicodeSMTPCharacterSet via
        // .subtracting(deprecatedFormatChars).
        let permissive: (String) -> Bool = { _ in true }
        let deprecatedChars: [(String, String)] = [
            ("\u{206A}", "U+206A Inhibit Symmetric Swapping (first deprecated format char)"),
            ("\u{206F}", "U+206F Nominal Digit Shapes (last deprecated format char)"),
        ]
        for (char, name) in deprecatedChars {
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part"
            )
        }
    }

    func testUnassignedSSPCharsRejectedInLocalPart() {
        // The entire Supplementary Special-Purpose Plane (SSP, U+E0000-U+EFFFF) must be
        // rejected. The SSP contains the deprecated Tags block (U+E0000-U+E007F), the
        // Variation Selectors Supplement (U+E0100-U+E01EF), and two currently-unassigned
        // gaps (U+E0080-U+E00FF and U+E01F0-U+EFFFF). All are invisible or undefined and
        // have no legitimate use in email addresses. The explicit scalar guard covers the
        // full range U+E0000-U+10FFFF (SSP + Supplementary PUA-A/B).
        let permissive: (String) -> Bool = { _ in true }
        let unassignedSSP: [(Unicode.Scalar, String)] = [
            (Unicode.Scalar(0xE0080)!, "U+E0080 unassigned SSP gap 1 (first)"),
            (Unicode.Scalar(0xE00FF)!, "U+E00FF unassigned SSP gap 1 (last)"),
            (Unicode.Scalar(0xE01F0)!, "U+E01F0 unassigned SSP gap 2 (first)"),
            (Unicode.Scalar(0xEFFFF)!, "U+EFFFF unassigned SSP gap 2 (last)"),
        ]
        for (scalar, name) in unassignedSSP {
            let char = String(scalar)
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part (unassigned SSP)"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part (unassigned SSP)"
            )
        }
        // Confirm SMP characters just below the SSP remain accepted
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user\u{1F600}@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "U+1F600 (emoji, SMP) must remain accepted — only SSP and above are blocked"
        )
    }

    // MARK: - Bug 2: Supplementary PUA (U+F0000-U+10FFFF)

    func testSupplementaryPrivateUseAreaRejectedInLocalPart() {
        // Supplementary Private Use Area-A (U+F0000-U+FFFFF) and -B (U+100000-U+10FFFF)
        // carry the same spoofing risk as the BMP Private Use Area (U+E000-U+F8FF),
        // which is already blocked. Private-use characters have no standardised rendering
        // and can appear identical to common glyphs in custom fonts.
        let permissive: (String) -> Bool = { _ in true }
        let supplementaryPUAChars: [(Unicode.Scalar, String)] = [
            (Unicode.Scalar(0xF0000)!, "U+F0000 Supplementary PUA-A first"),
            (Unicode.Scalar(0xF0001)!, "U+F0001 Supplementary PUA-A"),
            (Unicode.Scalar(0xFFFFD)!, "U+FFFFD Supplementary PUA-A last valid"),
            (Unicode.Scalar(0x100000)!, "U+100000 Supplementary PUA-B first"),
            (Unicode.Scalar(0x100001)!, "U+100001 Supplementary PUA-B"),
            (Unicode.Scalar(0x10FFFD)!, "U+10FFFD Supplementary PUA-B last valid"),
        ]
        for (scalar, name) in supplementaryPUAChars {
            let char = String(scalar)
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com", compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part (supplementary PUA spoofing prevention)"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com", compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part (supplementary PUA spoofing prevention)"
            )
        }
        // Confirm legitimate SMP characters (emoji, historic scripts) remain accepted
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user\u{1F600}@site.com", compatibility: .unicode, domainValidator: permissive),
            "U+1F600 (emoji, SMP) must still be accepted"
        )
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user\u{1D400}@site.com", compatibility: .unicode, domainValidator: permissive),
            "U+1D400 (Mathematical Bold A, SMP) must still be accepted"
        )
    }

    // MARK: - Review: Missing edge case tests (NUL / CRLF — correct rejection already implemented)

    func testNulCharacterRejectedInLocalPart() {
        // NUL (U+0000) is a C0 control character absent from both atextCharacterSet and
        // qtextSMTPCharacterSet; it must be rejected in both dot-atom and quoted-string local parts.
        let permissive: (String) -> Bool = { _ in true }
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user\u{0000}@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "NUL (U+0000) must be rejected in dot-atom local part"
        )
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "\"user\u{0000}\"@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "NUL (U+0000) must be rejected in quoted-string local part"
        )
    }

    func testCrLfRejectedInLocalPart() {
        // CR (U+000D) and LF (U+000A) are the SMTP line-terminator bytes.
        // Allowing them in a local part enables SMTP header injection.
        // Both are C0 controls absent from atextCharacterSet and qtextSMTPCharacterSet.
        let permissive: (String) -> Bool = { _ in true }
        for (char, name) in [("\u{000D}", "CR U+000D"), ("\u{000A}", "LF U+000A")] {
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part (SMTP injection prevention)"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part (SMTP injection prevention)"
            )
        }
    }

    // MARK: - Unicode noncharacter and reserved codepoint exclusions

    func testUnicodeNonCharactersRejectedInLocalPart() {
        // Unicode permanently-reserved noncharacters (U+FDD0–U+FDEF, U+FFFE, U+FFFF)
        // have no defined semantics and per Unicode §23.7 are "forbidden for use in
        // open interchange of Unicode text data." Both local-part formats must reject them.
        let permissive: (String) -> Bool = { _ in true }
        let nonCharacters: [(Unicode.Scalar, String)] = [
            (Unicode.Scalar(0xFDD0)!, "U+FDD0 (first noncharacter in FDD0–FDEF range)"),
            (Unicode.Scalar(0xFDEF)!, "U+FDEF (last noncharacter in FDD0–FDEF range)"),
            (Unicode.Scalar(0xFFFE)!, "U+FFFE (BMP noncharacter)"),
            (Unicode.Scalar(0xFFFF)!, "U+FFFF (BMP noncharacter)"),
        ]
        for (scalar, name) in nonCharacters {
            let char = String(scalar)
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part"
            )
        }
    }

    func testReservedFormatCharU2065RejectedInLocalPart() {
        // U+2065 is unassigned/reserved and sits between invisible format chars (U+2060–U+2064)
        // and bidi formatting chars (U+2066–U+2069). It must be excluded like its neighbours.
        let permissive: (String) -> Bool = { _ in true }
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user\u{2065}@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "U+2065 (reserved format char) must be rejected in dot-atom local part"
        )
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "\"user\u{2065}\"@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "U+2065 (reserved format char) must be rejected in quoted-string local part"
        )
        // Confirm neighbours remain correctly handled
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user\u{2064}@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "U+2064 (Invisible Plus, already excluded) must still be rejected"
        )
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user\u{2066}@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "U+2066 (LRI bidi char, already excluded) must still be rejected"
        )
    }

    func testEscapedMultiScalarClusterRejectedInUnicodeQuotedString() {
        // RFC 5321 §3.3: quoted-pair = "\" (VCHAR / WSP) — exactly one printable ASCII character.
        // A multi-scalar grapheme cluster in an escape position must be rejected even if its
        // first scalar is ASCII-printable (e.g. e + U+0301 combining acute = 2 scalars).
        let permissive: (String) -> Bool = { _ in true }
        // "\" followed by e+U+0301 (two-scalar grapheme cluster) in a quoted local part
        let twoScalarEscaped = "\"\\" + "e\u{0301}" + "\"@site.com"
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: twoScalarEscaped, compatibility: .unicode,
                domainValidator: permissive),
            "Escaped grapheme cluster with non-ASCII combining scalar must be rejected (RFC 5321: quoted-pair is ASCII-only)"
        )
        // Single-scalar ASCII escape must remain valid
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "\"\\e\"@site.com", compatibility: .unicode,
                domainValidator: permissive),
            "Escaped single ASCII scalar must still be accepted"
        )
    }

    func testSupplementaryPlanes4Through13RejectedInLocalPart() {
        // Planes 4–13 (U+40000–U+DFFFF) are entirely unassigned in Unicode and must be rejected.
        let permissive: (String) -> Bool = { _ in true }
        let planeProbes: [(Unicode.Scalar, String)] = [
            (Unicode.Scalar(0x40000)!, "U+40000 (first scalar of Plane 4, unassigned)"),
            (Unicode.Scalar(0x7FFFF)!, "U+7FFFF (last scalar of Plane 7, unassigned)"),
            (Unicode.Scalar(0x80000)!, "U+80000 (first scalar of Plane 8, unassigned)"),
            (Unicode.Scalar(0xDFFFF)!, "U+DFFFF (last scalar of Plane 13, unassigned)"),
        ]
        for (scalar, name) in planeProbes {
            let char = String(scalar)
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part"
            )
        }
        // SMP (Plane 1) characters must remain accepted — the fix must not over-reach
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user\u{1F600}@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "U+1F600 (emoji, SMP Plane 1) must still be accepted"
        )
        // U+3FFFF is a Unicode §23.7 noncharacter (U+nFFFF pattern, n=3) and must be rejected.
        // It was previously incorrectly asserted as accepted.
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user\u{3FFFF}@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "U+3FFFF (Plane 3 noncharacter per §23.7) must be rejected"
        )
    }

    // MARK: - Plane 1–3 supplementary noncharacter exclusions

    func testSupplementaryNonCharactersPlanes1Through3RejectedInLocalPart() {
        // Unicode §23.7: for every plane n=1..16, U+nFFFE and U+nFFFF are permanently reserved
        // noncharacters "forbidden for use in open interchange of Unicode text data."
        // Planes 1 (SMP), 2 (SIP), and 3 (TIP) each have two such noncharacters that were
        // previously not covered by the Planes 4-13 or SSP/PUA scalar guards.
        let permissive: (String) -> Bool = { _ in true }
        let plane123NonChars: [(Unicode.Scalar, String)] = [
            (Unicode.Scalar(0x1FFFE)!, "U+1FFFE (Plane 1 / SMP noncharacter)"),
            (Unicode.Scalar(0x1FFFF)!, "U+1FFFF (Plane 1 / SMP noncharacter)"),
            (Unicode.Scalar(0x2FFFE)!, "U+2FFFE (Plane 2 / SIP noncharacter)"),
            (Unicode.Scalar(0x2FFFF)!, "U+2FFFF (Plane 2 / SIP noncharacter)"),
            (Unicode.Scalar(0x3FFFE)!, "U+3FFFE (Plane 3 / TIP noncharacter)"),
            (Unicode.Scalar(0x3FFFF)!, "U+3FFFF (Plane 3 / TIP noncharacter)"),
        ]
        for (scalar, name) in plane123NonChars {
            let char = String(scalar)
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(char)@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part (Unicode §23.7 noncharacter)"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(char)\"@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part (Unicode §23.7 noncharacter)"
            )
        }
        // Confirm adjacent assigned scalars remain accepted
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user\u{1FFFD}@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "U+1FFFD (last assigned Plane 1 scalar, Linear B Syllabary) must remain accepted"
        )
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user\u{2FFFD}@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "U+2FFFD (last assigned Plane 2 scalar) must remain accepted"
        )
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user\u{3FFFD}@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "U+3FFFD (last assigned Plane 3 scalar) must remain accepted"
        )
    }

    // MARK: - Unicode space-like characters (Zs category) exclusion

    func testUnicodeSpaceCharsRejectedInLocalPart() {
        // Unicode space-like characters (Zs category, excluding U+0020 which is already blocked
        // by the atext definition) must be rejected in both dot-atom and quoted-string local parts.
        // They are visually indistinguishable from regular ASCII space (U+0020) in most fonts,
        // enabling account-duplication / spoofing: an attacker could register
        // "user\u{00A0}name@domain.com" which displays identically to "username@domain.com" or
        // "user name@domain.com" (the latter being an invalid dot-atom anyway, but the former
        // is a real, different account).  Consistent with already-blocked U+200B-U+200D (which
        // immediately follow the U+2000-U+200A block).
        let permissive: (String) -> Bool = { _ in true }
        let spaceChars: [(Unicode.Scalar, String)] = [
            (Unicode.Scalar(0x00A0)!, "U+00A0 NO-BREAK SPACE"),
            (Unicode.Scalar(0x1680)!, "U+1680 OGHAM SPACE MARK"),
            (Unicode.Scalar(0x2000)!, "U+2000 EN QUAD (first in space block)"),
            (Unicode.Scalar(0x2004)!, "U+2004 THREE-PER-EM SPACE"),
            (Unicode.Scalar(0x200A)!, "U+200A HAIR SPACE (last in space block)"),
            (Unicode.Scalar(0x202F)!, "U+202F NARROW NO-BREAK SPACE"),
            (Unicode.Scalar(0x205F)!, "U+205F MEDIUM MATHEMATICAL SPACE"),
            (Unicode.Scalar(0x3000)!, "U+3000 IDEOGRAPHIC SPACE"),
        ]
        for (scalar, name) in spaceChars {
            let ch = String(scalar)
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "user\(ch)name@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in dot-atom local part (spoofing: visually space-like)"
            )
            XCTAssertNil(
                EmailSyntaxValidator.mailbox(from: "\"user\(ch)name\"@site.com",
                    compatibility: .unicode, domainValidator: permissive),
                "\(name) must be rejected in quoted-string local part (spoofing: visually space-like)"
            )
        }
        // Confirm neighbours of the U+2000-U+200A block are handled correctly:
        // U+200B (Zero Width Space) — already blocked as a zero-width char, must remain rejected.
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user\u{200B}name@site.com",
                compatibility: .unicode, domainValidator: permissive),
            "U+200B (ZWS, just above space block) must remain rejected"
        )
    }

    // MARK: - Address literal: General-address-literal not supported
    //
    // RFC 5321 §4.1.3 defines `address-literal = "[" ( IPv4-address-literal /
    // IPv6-address-literal / General-address-literal ) "]"`, where
    // `General-address-literal = Standardized-tag ":" 1*dcontent` carries
    // future tag types via the IANA Address Literal Tags registry. This
    // implementation deliberately supports only `IPv4-address-literal` and
    // `IPv6:` literals — any other Standardized-tag form must be rejected.
    // These tests pin that scope so a future tag (e.g. one from the IANA
    // registry beyond IPv6) can't be silently accepted by accident.
    func testGeneralAddressLiteralWithUnknownTagRejected() {
        let permissive: (String) -> Bool = { _ in true }
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user@[FOOTAG:bar]", allowAddressLiteral: true,
                                         domainValidator: permissive),
            "Unknown Standardized-tag form must be rejected (RFC 5321 §4.1.3 General-address-literal not supported)")
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user@[X:1.2.3.4]", allowAddressLiteral: true,
                                         domainValidator: permissive),
            "Single-letter Standardized-tag form must be rejected — only IPv4 and IPv6: tags are accepted")
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user@[ipv6:::1]", allowAddressLiteral: true,
                                         domainValidator: permissive),
            "IPv6 tag is case-sensitive per IANA registry — lowercase `ipv6:` must be rejected")
    }

    // MARK: - Single-label host rejection via main validator
    //
    // The default `domainValidator` is `TLDDomainValidator._isPubliclyDeliverable`,
    // which requires ≥2 labels (RFC 5321 FQDN). TLDDomainValidatorTests covers the
    // closure directly; this test pins the wiring through the main validator so a
    // future regression that bypasses the closure for single-label hosts surfaces
    // here too.
    func testSingleLabelHostRejectedViaDefaultValidator() {
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@localhost"),
                     "Single-label host `localhost` must be rejected by default validator")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@server"),
                     "Single-label host `server` must be rejected by default validator")
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "user@mailserver"),
                     "Single-label host `mailserver` must be rejected by default validator")
        XCTAssertFalse(EmailSyntaxValidator.correctlyFormatted("user@localhost"),
                       "Boolean form must agree with mailbox(from:) on single-label rejection")
    }

    // MARK: - IPv4-mapped IPv6 end-to-end

    func testIPv4MappedIPv6LiteralEndToEnd() {
        // IPAddressValidatorTests covers the matcher; this test pins the full
        // EmailSyntaxValidator flow for IPv4-mapped IPv6 literals so callers
        // can rely on `[IPv6:::ffff:…]` round-tripping through the parser.
        let permissive: (String) -> Bool = { _ in true }
        let candidate = "user@[IPv6:::ffff:192.0.2.1]"
        let parsed = EmailSyntaxValidator.mailbox(from: candidate,
                                                  allowAddressLiteral: true,
                                                  domainValidator: permissive)
        XCTAssertEqual(parsed?.localPart, .dotAtom("user"),
                       "Local part must round-trip through IPv4-mapped IPv6 literal flow")
        XCTAssertEqual(parsed?.host, .addressLiteral("IPv6:::ffff:192.0.2.1"),
                       "IPv4-mapped IPv6 literal must round-trip through full email flow (RFC 4291 §2.5.5)")
        XCTAssertTrue(EmailSyntaxValidator.correctlyFormatted(candidate,
                                                              allowAddressLiteral: true,
                                                              domainValidator: permissive),
                      "Boolean form must agree with mailbox(from:) on IPv4-mapped IPv6 literals")
    }

    // MARK: - Address literal edge cases (regression guard)

    func testIPv6AddressLiteralEdgeCasesRejected() {
        // These edge cases exercise the IPv6-literal parsing path with malformed input.
        // All must be rejected regardless of the allowAddressLiteral flag.
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user@[IPv6:]", allowAddressLiteral: true),
            "Empty IPv6 literal (IPv6: with no address) must be rejected"
        )
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user@[IPv6:not-valid]", allowAddressLiteral: true),
            "Non-IPv6 string after IPv6: tag must be rejected"
        )
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user@[SMTP:example.com]", allowAddressLiteral: true),
            "Non-standard address literal type (SMTP:) must be rejected"
        )
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user@[]", allowAddressLiteral: true),
            "Empty address literal [] must be rejected"
        )
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user@[ 127.0.0.1]", allowAddressLiteral: true),
            "IPv4 literal with leading space must be rejected"
        )
        XCTAssertNil(
            EmailSyntaxValidator.mailbox(from: "user@[127.0.0.1 ]", allowAddressLiteral: true),
            "IPv4 literal with trailing space must be rejected"
        )
        // Confirm a valid IPv6 literal still works
        XCTAssertNotNil(
            EmailSyntaxValidator.mailbox(from: "user@[IPv6:::1]", allowAddressLiteral: true,
                domainValidator: { _ in true }),
            "Valid loopback IPv6 literal must still be accepted"
        )
    }

}
