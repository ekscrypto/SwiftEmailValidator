import Foundation
import EmailValidator

enum EvanRobertsonAscii: ValidatorAdapter {
    static let name = "evanrobertson/EmailValidator (ASCII)"
    static let link = "https://github.com/evanrobertson/EmailValidator"
    static let rfcCoverage = "RFC 5322"
    static let domainValidation = false
    static let claimedCapabilities: Capability = [.rfc5322, .rfc5321IPLit]
    static let referenceMethod: ValidationMethod = .swiftEmailAscii
    static func validate(_ email: String) -> Bool {
        EmailValidator.validate(email: email, allowTopLevelDomains: false, allowInternational: false)
    }
}

enum EvanRobertsonInternational: ValidatorAdapter {
    static let name = "evanrobertson/EmailValidator (international)"
    static let link = "https://github.com/evanrobertson/EmailValidator"
    static let rfcCoverage = "RFC 5322 + RFC 653x (i18n)"
    static let domainValidation = false
    static let claimedCapabilities: Capability = [.rfc5322, .rfc5321IPLit, .rfc6531]
    static let referenceMethod: ValidationMethod = .swiftEmailUnicode
    static func validate(_ email: String) -> Bool {
        EmailValidator.validate(email: email, allowTopLevelDomains: false, allowInternational: true)
    }
}
