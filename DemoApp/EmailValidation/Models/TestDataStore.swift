import Combine
import Foundation
import SwiftUI

/// Main data store for all test cases and validation results
@MainActor
class TestDataStore: ObservableObject {
    @Published var testCases: [EmailTestCase] = []
    @Published var validationResults: [ValidationResult] = []
    @Published var isLoading: Bool = false
    @Published var hasLoaded: Bool = false

    func loadAndValidate() async {
        guard !hasLoaded else { return }

        isLoading = true

        // Load test cases
        testCases = TestData.allTestCases

        // Run validation on background thread
        let cases = testCases

        let results = await Task.detached(priority: .userInitiated) {
            let service = ValidationService()
            return service.validateAll(cases)
        }.value

        validationResults = results
        isLoading = false
        hasLoaded = true
    }

    /// Get statistics for a specific validation method
    func statistics(for method: ValidationMethod) -> MethodStatistics {
        var correct = 0
        var truePositives = 0
        var trueNegatives = 0
        var falsePositives = 0
        var falseNegatives = 0

        for result in validationResults {
            let expected = result.testCase.expectedResult(for: method)
            let actual = result.results[method] ?? false

            if actual == expected {
                correct += 1
                if expected {
                    truePositives += 1
                } else {
                    trueNegatives += 1
                }
            } else {
                if actual {
                    falsePositives += 1
                } else {
                    falseNegatives += 1
                }
            }
        }

        return MethodStatistics(
            method: method,
            totalTests: validationResults.count,
            correctResults: correct,
            truePositives: truePositives,
            trueNegatives: trueNegatives,
            falsePositives: falsePositives,
            falseNegatives: falseNegatives
        )
    }

    /// Get all results for a specific category
    func results(for category: TestCategory) -> [ValidationResult] {
        validationResults.filter { $0.testCase.category == category }
    }

    /// Get results where a specific method was incorrect
    func incorrectResults(for method: ValidationMethod) -> [ValidationResult] {
        validationResults.filter { !$0.isCorrect(for: method) }
    }

    /// Get count of test cases per category
    func testCount(for category: TestCategory) -> Int {
        testCases.filter { $0.category == category }.count
    }

    /// Get accuracy for a method within a specific category
    func accuracy(for method: ValidationMethod, in category: TestCategory) -> Double {
        let categoryResults = results(for: category)
        guard !categoryResults.isEmpty else { return 0 }
        let correct = categoryResults.filter { $0.isCorrect(for: method) }.count
        return Double(correct) / Double(categoryResults.count)
    }
}

