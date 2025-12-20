import Foundation

/// Service that orchestrates validation across all methods
struct ValidationService: Sendable {

    nonisolated init() {}

    /// Validate a single email against all validation methods
    nonisolated func validate(_ email: String) -> [ValidationMethod: Bool] {
        [
            .nsDataDetector: NSDataDetectorValidator.validate(email),
            .nsPredicateRFC: NSPredicateRFCValidator.validate(email),
            .nsPredicateSimple: NSPredicateSimpleValidator.validate(email),
            .swiftEmailAscii: SwiftEmailValidatorWrapper.validateAscii(email),
            .swiftEmailAsciiUnicode: SwiftEmailValidatorWrapper.validateAsciiWithUnicode(email),
            .swiftEmailUnicode: SwiftEmailValidatorWrapper.validateUnicode(email)
        ]
    }

    /// Validate all test cases and return results
    nonisolated func validateAll(_ testCases: [EmailTestCase]) -> [ValidationResult] {
        testCases.map { testCase in
            ValidationResult(testCase: testCase, results: validate(testCase.email))
        }
    }
}
