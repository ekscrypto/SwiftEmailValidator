import Foundation

/// Result of validating a single test case across all methods
struct ValidationResult: Identifiable, Hashable, Sendable {
    let id = UUID()
    let testCase: EmailTestCase
    let results: [ValidationMethod: Bool]

    /// Whether a specific method returned the correct result
    func isCorrect(for method: ValidationMethod) -> Bool {
        guard let result = results[method] else { return false }
        return result == testCase.expectedResult(for: method)
    }

    /// The result returned by a specific method
    func result(for method: ValidationMethod) -> Bool? {
        results[method]
    }

    /// Count of methods that returned correct results
    var correctCount: Int {
        ValidationMethod.allCases.filter { isCorrect(for: $0) }.count
    }

    /// Count of methods that returned incorrect results
    var incorrectCount: Int {
        ValidationMethod.allCases.count - correctCount
    }

    static func == (lhs: ValidationResult, rhs: ValidationResult) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Statistics for a single validation method
struct MethodStatistics: Identifiable {
    let method: ValidationMethod
    let totalTests: Int
    let correctResults: Int
    let truePositives: Int  // Correctly identified valid emails
    let trueNegatives: Int  // Correctly identified invalid emails
    let falsePositives: Int // Invalid emails marked as valid
    let falseNegatives: Int // Valid emails marked as invalid

    var id: String { method.id }

    var incorrectResults: Int { totalTests - correctResults }

    var accuracy: Double {
        guard totalTests > 0 else { return 0 }
        return Double(correctResults) / Double(totalTests)
    }

    var accuracyPercentage: String {
        String(format: "%.1f%%", accuracy * 100)
    }
}
