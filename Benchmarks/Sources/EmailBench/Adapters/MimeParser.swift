import Foundation
import MimeEmailParser

enum MimeParserAdapter: ValidatorAdapter {
    static let name = "igorrendulic/MimeEmailParser"
    static let link = "https://github.com/igorrendulic/MimeEmailParser"
    static let rfcCoverage = "RFC 5322 + RFC 2047 / 6532"
    static let domainValidation = false
    static let referenceMethod: ValidationMethod = .swiftEmailUnicode

    nonisolated(unsafe) private static let parser = MimeEmailParser()

    static func validate(_ email: String) -> Bool {
        do {
            _ = try parser.parseSingleAddress(address: email)
            return true
        } catch {
            return false
        }
    }
}
