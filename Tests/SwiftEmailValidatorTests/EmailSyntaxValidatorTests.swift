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
            domainRules: [["com"]])?.localPart
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
    
    func testQuotedTextLocalPart() {
        XCTAssertEqual(baseMailboxLocalPartValidation(#""email"@site.com"#), .quotedString(#""email""#))
        XCTAssertEqual(baseMailboxLocalPartValidation(#""Mickey Mouse"@disney.com"#), .quotedString("\"Mickey Mouse\""), "Spaces are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation(#"""@site.com"#), .quotedString("\"\""), "DQUOTE *QcontentSMTP DQUOTE implies empty quoted strings are allowed for local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\" \"@site.com"), .quotedString("\" \""), "Spaces are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"!\"@site.com"), .quotedString("\"!\""), "! are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"#\"@site.com"), .quotedString("\"#\""), "# are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"$\"@site.com"), .quotedString("\"$\""), "$ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"%\"@site.com"), .quotedString("\"%\""), "% are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"&\"@site.com"), .quotedString("\"&\""), "& are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"'\"@site.com"), .quotedString("\"'\""), "Single-quote are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"(\"@site.com"), .quotedString("\"(\""), "( are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\")\"@site.com"), .quotedString("\")\""), ") are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"*\"@site.com"), .quotedString("\"*\""), "* are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"+\"@site.com"), .quotedString("\"+\""), "+ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\",\"@site.com"), .quotedString("\",\""), ", are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"-\"@site.com"), .quotedString("\"-\""), "- are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\".\"@site.com"), .quotedString("\".\""), ". are allowed without restriction in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"/\"@site.com"), .quotedString("\"/\""), "/ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\":\"@site.com"), .quotedString("\":\""), ": are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\";\"@site.com"), .quotedString("\";\""), "; are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"<\"@site.com"), .quotedString("\"<\""), "< are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"=\"@site.com"), .quotedString("\"=\""), "= are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\">\"@site.com"), .quotedString("\">\""), "> are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"?\"@site.com"), .quotedString("\"?\""), "? are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"@\"@site.com"), .quotedString("\"@\""), "@ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"[\"@site.com"), .quotedString("\"[\""), "[ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"]\"@site.com"), .quotedString("\"]\""), "] are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"^\"@site.com"), .quotedString("\"^\""), "^ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"_\"@site.com"), .quotedString("\"_\""), "_ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"`\"@site.com"), .quotedString("\"`\""), "` are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"{\"@site.com"), .quotedString("\"{\""), "{ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"|\"@site.com"), .quotedString("\"|\""), "| are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"}\"@site.com"), .quotedString("\"}\""), "} are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation("\"~\"@site.com"), .quotedString("\"~\""), "~ are allowed in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation(#""\\"@site.com"#), .quotedString("\"\\\\\""), "Backslashes are allowed when escaped in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation(#""\t"@site.com"#), .quotedString("\"\\t\""), "The next ascii (32-126) after a backslash is accepted as is")
        XCTAssertEqual(baseMailboxLocalPartValidation(#""\""@site.com"#), .quotedString("\"\\\"\""), "Double-quotes are allowed when escaped in quoted local part")
        XCTAssertEqual(baseMailboxLocalPartValidation(#""email@notadomain.com"@site.com"#), .quotedString("\"email@notadomain.com\""), "Since the @ is within the double quotes it is considered as the local part")
        XCTAssertNil(baseMailboxLocalPartValidation("\"\t\"@site.com"),"Tab is outside the 32-126 ascii range allowed in quoted text")
        XCTAssertNil(baseMailboxLocalPartValidation(#""\"@site.com"#),"The double-quote following the escape would have been escaped so the @site.com would still be part of the local part and no closing double-quotes would be found")
        XCTAssertNil(baseMailboxLocalPartValidation(#""email@notadomain.com""#), "Entire email address is within double-quotes so the whole thing would be considered the local part with no @ domain after the quotes this should be rejected")
    }
    
    func testEmailWithIPv4AddressLiteral() {
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "Santa.Claus@[127.0.0.1]", allowAddressLiteral: false))
        guard let mailbox = EmailSyntaxValidator.mailbox(from: "Santa.Claus@[127.0.0.1]", allowAddressLiteral: true) else {
            XCTFail("When allowing address literals, email addresses should be valid if they specific @[<IPv4 Address>]")
            return
        }
        XCTAssertEqual(mailbox.localPart, .dotAtom("Santa.Claus"))
        XCTAssertEqual(mailbox.host, .addressLiteral("127.0.0.1"))
    }
    
    func testEmailWithIPv6AddressLiteral() {
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: "Santa.Claus@[IPv6:fe80::1]", allowAddressLiteral: false))
        guard let mailbox = EmailSyntaxValidator.mailbox(from: "Santa.Claus@[IPv6:fe80::1]", allowAddressLiteral: true) else {
            XCTFail("When allowing address literals, email addresses should be valid if they specific @[IPv6:<IPv6 Address>]")
            return
        }
        XCTAssertEqual(mailbox.localPart, .dotAtom("Santa.Claus"))
        XCTAssertEqual(mailbox.host, .addressLiteral("IPv6:fe80::1"))
    }
    
    func testLocalPartMaximumLength() {
        let maxlocalPart = String(repeating: "x", count: 64)
        let testEmail = "\(maxlocalPart)@site.com"
        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: testEmail)?.localPart, .dotAtom(maxlocalPart))
        let shouldBeInvalidEmail = "\(maxlocalPart)x@site.com"
        XCTAssertNil(EmailSyntaxValidator.mailbox(from: shouldBeInvalidEmail))
    }
    
//    func testLocalPartWithQEncoding() {
//        let testEmail = "=?iso-8851-1?q?Santa=20Claus@site.com?="
//        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: testEmail)?.localPart, .dotAtom("=?iso-8851-1?q?Santa=20Claus?="))
//    }
//
//    func testLocalPartWithBEncoding() {
//        let testEmail = "=?utf-8?B?7ZWcQHgu7ZWc6rWt?="
//        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: testEmail)?.localPart, .dotAtom("한"))
//        XCTAssertEqual(EmailSyntaxValidator.mailbox(from: testEmail)?.host, .domain("x.한국"))
//    }
}
