import Foundation

// Mirrors DemoApp/EmailValidation/Models/ValidationMethod.swift.
// Kept identical so the copied TestData.swift compiles unchanged
// and `expectedOverrides: [.swiftEmailUnicode: true]` still resolves.
enum ValidationMethod: String, CaseIterable, Hashable, Sendable {
    case nsDataDetector = "NSDataDetector"
    case nsPredicateRFC = "NSPredicate (RFC)"
    case nsPredicateSimple = "NSPredicate (Simple)"
    case swiftEmailAscii = "SwiftEmail (ASCII)"
    case swiftEmailAsciiUnicode = "SwiftEmail (ASCII+Unicode)"
    case swiftEmailUnicode = "SwiftEmail (Unicode)"
}
