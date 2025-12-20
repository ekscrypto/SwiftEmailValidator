import Foundation

/// Categories of email test cases, grouped by reason for validity/invalidity
enum TestCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    // Invalid categories
    case missingAtSymbol = "Missing @ symbol"
    case emptyLocalPart = "Empty local part"
    case leadingTrailingDots = "Leading/trailing dots"
    case consecutiveDots = "Consecutive dots"
    case invalidDotAtomChars = "Invalid dot-atom characters"
    case invalidQuotedString = "Invalid quoted string"
    case invalidEscapeSequence = "Invalid escape sequence"
    case localPartTooLong = "Local part too long (>64)"
    case invalidDomain = "Invalid domain"
    case invalidIPv4Literal = "Invalid IPv4 literal"
    case invalidIPv6Literal = "Invalid IPv6 literal"
    case ipv6ZoneIdentifier = "IPv6 zone identifier"
    case unicodeInAsciiMode = "Unicode (ASCII mode)"
    case controlCharacters = "Control characters"
    case bidirectionalOverride = "Bidirectional override"
    case invalidRFC2047 = "Invalid RFC2047"

    // Valid categories
    case validStandard = "Valid standard"
    case validSpecialChars = "Valid special chars"
    case validQuotedString = "Valid quoted string"
    case validUnicode = "Valid Unicode"
    case validIPLiteral = "Valid IP literal"
    case validRFC2047 = "Valid RFC2047"
    case validBoundary = "Valid boundary (63-64 chars)"

    var id: String { rawValue }

    var isValidCategory: Bool {
        switch self {
        case .validStandard, .validSpecialChars, .validQuotedString,
             .validUnicode, .validIPLiteral, .validRFC2047, .validBoundary:
            return true
        default:
            return false
        }
    }

    var icon: String {
        isValidCategory ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    static var invalidCategories: [TestCategory] {
        allCases.filter { !$0.isValidCategory }
    }

    static var validCategories: [TestCategory] {
        allCases.filter { $0.isValidCategory }
    }
}
