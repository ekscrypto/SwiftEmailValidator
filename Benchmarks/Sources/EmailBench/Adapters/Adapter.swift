import Foundation

protocol ValidatorAdapter {
    static var name: String { get }
    static var link: String { get }
    static var rfcCoverage: String { get }
    static var domainValidation: Bool { get }
    static var claimedCapabilities: Capability { get }
    static var referenceMethod: ValidationMethod { get }
    static func validate(_ email: String) -> Bool
}
