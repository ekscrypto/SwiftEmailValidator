import Foundation

/// The different email validation methods being compared
enum ValidationMethod: String, CaseIterable, Identifiable, Hashable, Sendable {
    case nsDataDetector = "NSDataDetector"
    case nsPredicateRFC = "NSPredicate (RFC)"
    case nsPredicateSimple = "NSPredicate (Simple)"
    case swiftEmailAscii = "SwiftEmail (ASCII)"
    case swiftEmailAsciiUnicode = "SwiftEmail (ASCII+Unicode)"
    case swiftEmailUnicode = "SwiftEmail (Unicode)"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .nsDataDetector: return "DataDet"
        case .nsPredicateRFC: return "RFC"
        case .nsPredicateSimple: return "Simple"
        case .swiftEmailAscii: return "ASCII"
        case .swiftEmailAsciiUnicode: return "A+U"
        case .swiftEmailUnicode: return "Unicode"
        }
    }

    var description: String {
        switch self {
        case .nsDataDetector:
            return "Apple's NSDataDetector checking for mailto links"
        case .nsPredicateRFC:
            return "NSPredicate with RFC 5322-like regex pattern"
        case .nsPredicateSimple:
            return "NSPredicate with simple regex pattern"
        case .swiftEmailAscii:
            return "SwiftEmailValidator in ASCII mode (RFC 822)"
        case .swiftEmailAsciiUnicode:
            return "SwiftEmailValidator with RFC 2047 Unicode extension"
        case .swiftEmailUnicode:
            return "SwiftEmailValidator in full Unicode mode (RFC 6531)"
        }
    }

    var isNative: Bool {
        switch self {
        case .nsDataDetector, .nsPredicateRFC, .nsPredicateSimple:
            return true
        case .swiftEmailAscii, .swiftEmailAsciiUnicode, .swiftEmailUnicode:
            return false
        }
    }

    var color: String {
        switch self {
        case .nsDataDetector: return "blue"
        case .nsPredicateRFC: return "purple"
        case .nsPredicateSimple: return "orange"
        case .swiftEmailAscii: return "green"
        case .swiftEmailAsciiUnicode: return "teal"
        case .swiftEmailUnicode: return "mint"
        }
    }
}
