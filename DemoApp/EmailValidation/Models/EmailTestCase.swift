import Foundation

/// A single email test case with its expected validity
struct EmailTestCase: Identifiable, Hashable, Sendable {
    let id = UUID()
    let email: String
    let category: TestCategory
    let expectedValid: Bool
    let description: String?
    /// Method-specific expected results that override the default expectedValid
    let expectedOverrides: [ValidationMethod: Bool]

    init(email: String, category: TestCategory, expectedValid: Bool, description: String? = nil, expectedOverrides: [ValidationMethod: Bool] = [:]) {
        self.email = email
        self.category = category
        self.expectedValid = expectedValid
        self.description = description
        self.expectedOverrides = expectedOverrides
    }

    /// Get the expected result for a specific validation method
    func expectedResult(for method: ValidationMethod) -> Bool {
        expectedOverrides[method] ?? expectedValid
    }

    /// Display-safe version of the email (escapes control characters)
    var displayEmail: String {
        var result = ""
        for scalar in email.unicodeScalars {
            if scalar.value < 32 || (scalar.value >= 0x7F && scalar.value <= 0x9F) {
                result += String(format: "\\u{%04X}", scalar.value)
            } else {
                result += String(scalar)
            }
        }
        return result
    }
}
