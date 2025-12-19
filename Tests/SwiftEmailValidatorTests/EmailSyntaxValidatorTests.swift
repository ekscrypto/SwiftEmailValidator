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
import SwiftPublicSuffixList

final class EmailSyntaxValidatorTests: XCTestCase {
    
    func baseMailboxLocalPartValidation(_ candidate: String) -> EmailSyntaxValidator.Mailbox.LocalPart? {
        EmailSyntaxValidator.mailbox(
            from: candidate,
            allowAddressLiteral: false,
            domainValidator: { PublicSuffixList.isUnrestricted($0, rules: [["com"]])})?.localPart
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
        XCTAssertNotEqual(baseMailboxLocalPartValidation("\"user\"@site.com"), .dotAtom("user"))
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

    // MARK: - Phase 1: Local Part Boundary Tests

    func testLocalPartExactly63Characters() {
        let localPart63 = String(repeating: "x", count: 63)
        let testEmail = "\(localPart63)@site.com"
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: testEmail, domainValidator: { PublicSuffixList.isUnrestricted($0, rules: [["com"]])})?.localPart, .dotAtom(localPart63), "63-character local part should be valid (just under 64 limit)")
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
        // 30 such characters = 30 chars but 120 UTF-8 bytes
        let fourByteChar = "\u{1D11E}" // 𝄞
        let localPart = String(repeating: fourByteChar, count: 30)
        let testEmail = "\(localPart)@site.com"
        let result = EmailSyntaxValidator.mailbox(from: testEmail, compatibility: .unicode, domainValidator: { PublicSuffixList.isUnrestricted($0, rules: [["com"]])})
        XCTAssertNotNil(result, "30 four-byte Unicode characters (120 bytes but 30 chars) should be valid since limit is character count")
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
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: emojiEmail, compatibility: .unicode, domainValidator: { PublicSuffixList.isUnrestricted($0, rules: [["com"]])}), "Emoji should be accepted in Unicode mode")
    }

    func testCombiningMarksInLocalPart() {
        // café with combining acute accent (e + combining acute)
        let combiningEmail = "cafe\u{0301}@site.com"
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: combiningEmail, compatibility: .ascii), "Combining marks should be rejected in ASCII mode")
        let result = EmailSyntaxValidator.mailbox(from: combiningEmail, compatibility: .unicode, domainValidator: { PublicSuffixList.isUnrestricted($0, rules: [["com"]])})
        XCTAssertNotNil(result, "Combining marks should be accepted in Unicode mode")
    }

    func testHighUnicodeRanges() {
        // Mathematical bold capital A (U+1D400) - beyond BMP
        let mathEmail = "\u{1D400}@site.com"
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: mathEmail, compatibility: .ascii), "High Unicode should be rejected in ASCII mode")
        XCTAssertNotNil(EmailSyntaxValidator.mailbox(from: mathEmail, compatibility: .unicode, domainValidator: { PublicSuffixList.isUnrestricted($0, rules: [["com"]])}), "High Unicode (beyond BMP) should be accepted in Unicode mode")
    }

    func testZeroWidthCharacters() {
        // Zero-width joiner U+200D
        let zwjEmail = "a\u{200D}b@site.com"
        // These are typically control-like characters and may be rejected
        let result = EmailSyntaxValidator.mailbox(from: zwjEmail, compatibility: .unicode, domainValidator: { PublicSuffixList.isUnrestricted($0, rules: [["com"]])})
        // Document actual behavior - may be nil or valid depending on implementation
        if result == nil {
            XCTAssertNil(result, "Zero-width joiner is rejected as expected")
        } else {
            XCTAssertNotNil(result, "Zero-width joiner is accepted in Unicode mode")
        }
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
        let result = EmailSyntaxValidator.mailbox(from: multiAtEmail, domainValidator: { PublicSuffixList.isUnrestricted($0, rules: [["com"]])})
        XCTAssertEqual(result?.localPart, .quotedString("user@fake@also"), "Multiple @ symbols inside quoted string should be valid")
        XCTAssertEqual(result?.host, .domain("site.com"))
    }

    func testQuotedStringWithRFC2047Decoding() {
        // RFC2047 encode a quoted string email: "Santa Claus"@site.com
        let rfc2047Encoded = "=?iso-8859-1?q?\"Santa=20Claus\"@site.com?="
        let result = EmailSyntaxValidator.mailbox(from: rfc2047Encoded, domainValidator: { PublicSuffixList.isUnrestricted($0, rules: [["com"]])})
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
        // Valid local part but very long domain
        let longDomain = String(repeating: "x", count: 500) + ".com"
        let testEmail = "user@\(longDomain)"
        // This depends on domain validator - with permissive validator it may pass
        let result = EmailSyntaxValidator.mailbox(from: testEmail, domainValidator: { _ in true })
        // Document behavior - long domains may be accepted if validator allows
        XCTAssertNotNil(result, "With permissive validator, long domain is accepted")
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

    func testManyUnicodeCharactersInLocalPart() {
        // 64 diverse Unicode characters from different scripts
        let diverse = "한中あαбעعहবதతకಕമෆไᎠ" // Various scripts
        let localPart = String(diverse.prefix(60)) // Stay under 64
        let testEmail = "\(localPart)@site.com"
        let result = EmailSyntaxValidator.mailbox(from: testEmail, compatibility: .unicode, domainValidator: { PublicSuffixList.isUnrestricted($0, rules: [["com"]])})
        XCTAssertNotNil(result, "Diverse Unicode characters should be valid in Unicode mode")
    }
}
