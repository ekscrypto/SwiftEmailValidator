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

    let validEmailAddresses: [String] = [
        "email@example.com",
        "firstname.lastname@example.com",
        "email@subdomain.example.com",
        "firstname+lastname@example.com",
        "email@123.123.123.123",
        "email@[123.123.123.123]",
        "\"email\"@example.com",
        "1234567890@example.com",
        "email@example-one.com",
        "_______@example.com",
        "email@example.name",
        "email@example.museum",
        "email@example.co.jp",
        "firstname-lastname@example.com"
    ]
    
    func baseMailboxLocalPartValidation(_ candidate: String) -> EmailSyntaxValidator.Mailbox.LocalPart? {
        EmailSyntaxValidator.mailbox(
            from: candidate,
            allowHostRoutes: false,
            allowAddressLiteral: false, domainRules: [["com"]])?.localPart
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
}
