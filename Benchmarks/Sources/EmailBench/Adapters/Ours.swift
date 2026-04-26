import Foundation
import SwiftEmailValidator

enum OursAscii: ValidatorAdapter {
    static let name = "SwiftEmailValidator (ASCII)"
    static let link = "https://github.com/ekscrypto/SwiftEmailValidator"
    static let rfcCoverage = "RFC 822 / 5321 / 5322"
    static let domainValidation = true
    static let referenceMethod: ValidationMethod = .swiftEmailAscii
    static func validate(_ email: String) -> Bool {
        EmailSyntaxValidator.correctlyFormatted(email, compatibility: .ascii, allowAddressLiteral: true)
    }
}

enum OursAsciiUnicode: ValidatorAdapter {
    static let name = "SwiftEmailValidator (ASCII + RFC 2047)"
    static let link = "https://github.com/ekscrypto/SwiftEmailValidator"
    static let rfcCoverage = "RFC 822 / 2047 / 5321 / 5322"
    static let domainValidation = true
    static let referenceMethod: ValidationMethod = .swiftEmailAsciiUnicode
    static func validate(_ email: String) -> Bool {
        EmailSyntaxValidator.correctlyFormatted(email, compatibility: .asciiWithUnicodeExtension, allowAddressLiteral: true)
    }
}

enum OursUnicode: ValidatorAdapter {
    static let name = "SwiftEmailValidator (Unicode)"
    static let link = "https://github.com/ekscrypto/SwiftEmailValidator"
    static let rfcCoverage = "RFC 5321 / 5322 / 6531"
    static let domainValidation = true
    static let referenceMethod: ValidationMethod = .swiftEmailUnicode
    static func validate(_ email: String) -> Bool {
        EmailSyntaxValidator.correctlyFormatted(email, compatibility: .unicode, allowAddressLiteral: true)
    }
}
