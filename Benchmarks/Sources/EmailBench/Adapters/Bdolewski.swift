import Foundation

// Regex vendored from https://github.com/bdolewski/SwiftEmailValidator (MIT)
// Reason for inlining: bdolewski's `EmailValidator` symbol has default (internal)
// access and cannot be imported across a module boundary. The author's README
// explicitly offers the file-copy path as a supported use.
enum BdolewskiAdapter: ValidatorAdapter {
    static let name = "bdolewski/SwiftEmailValidator"
    static let link = "https://github.com/bdolewski/SwiftEmailValidator"
    static let rfcCoverage = "RFC 5322 (regex)"
    static let domainValidation = false
    static let referenceMethod: ValidationMethod = .swiftEmailAscii

    private static let predicate: NSPredicate = {
        let regex = #"(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])"#
        return NSPredicate(format: "SELF MATCHES[c] %@", regex)
    }()

    static func validate(_ email: String) -> Bool {
        predicate.evaluate(with: email)
    }
}
