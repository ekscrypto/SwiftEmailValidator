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
        "firstname-lastname@example.com",
        #"much.”more\ unusual”@example.com"#,
        #"very.unusual.”@”.unusual.com@example.com"#,
        #"very.”(),:;<>[]”.VERY.”very@\\ "very”.unusual@strange.example.com"#,
    ]
}
