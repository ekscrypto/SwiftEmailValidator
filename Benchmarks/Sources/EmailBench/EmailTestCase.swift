import Foundation

// Mirrors DemoApp/EmailValidation/Models/EmailTestCase.swift init signature so
// TestData.swift can be copied from the DemoApp verbatim.
struct EmailTestCase: Hashable, Sendable {
    let email: String
    let category: TestCategory
    let expectedValid: Bool
    let description: String?
    let expectedOverrides: [ValidationMethod: Bool]

    init(email: String,
         category: TestCategory,
         expectedValid: Bool,
         description: String? = nil,
         expectedOverrides: [ValidationMethod: Bool] = [:]) {
        self.email = email
        self.category = category
        self.expectedValid = expectedValid
        self.description = description
        self.expectedOverrides = expectedOverrides
    }

    func expectedResult(for method: ValidationMethod) -> Bool {
        expectedOverrides[method] ?? expectedValid
    }
}
