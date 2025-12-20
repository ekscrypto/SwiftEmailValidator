import SwiftUI

/// Detail view for a single test case showing all method results
struct TestCaseDetailView: View {
    let result: ValidationResult

    var body: some View {
        List {
            emailSection
            categorySection
            expectedSection
            resultsSection
        }
        .navigationTitle("Test Case")
    }

    private var emailSection: some View {
        Section("Email Address") {
            VStack(alignment: .leading, spacing: 8) {
                Text(result.testCase.displayEmail)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)

                if result.testCase.email != result.testCase.displayEmail {
                    Text("Contains non-printable characters")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    private var categorySection: some View {
        Section("Category") {
            HStack {
                Image(systemName: result.testCase.category.icon)
                    .foregroundColor(result.testCase.category.isValidCategory ? .green : .red)
                Text(result.testCase.category.rawValue)
            }
        }
    }

    private var expectedSection: some View {
        Section("Expected Result") {
            HStack {
                Image(systemName: result.testCase.expectedValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.testCase.expectedValid ? .green : .red)
                Text(result.testCase.expectedValid ? "Valid" : "Invalid")
                    .font(.headline)
            }

            if let description = result.testCase.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var resultsSection: some View {
        Section("Validation Results") {
            ForEach(ValidationMethod.allCases) { method in
                MethodResultRow(method: method, result: result)
            }
        }
    }
}

/// Row showing a single method's result
struct MethodResultRow: View {
    let method: ValidationMethod
    let result: ValidationResult

    private var returned: Bool {
        result.results[method] ?? false
    }

    private var isCorrect: Bool {
        result.isCorrect(for: method)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(method.rawValue)
                    .font(.headline)

                Text(method.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(returned ? "VALID" : "INVALID")
                    .font(.caption.bold())
                    .foregroundColor(returned ? .green : .red)

                HStack(spacing: 4) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                    Text(isCorrect ? "Correct" : "Wrong")
                        .font(.caption2)
                }
                .foregroundColor(isCorrect ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        TestCaseDetailView(
            result: ValidationResult(
                testCase: EmailTestCase(
                    email: "test@example.com",
                    category: .validStandard,
                    expectedValid: true,
                    description: "Simple valid email"
                ),
                results: [
                    .nsDataDetector: true,
                    .nsPredicateRFC: true,
                    .nsPredicateSimple: true,
                    .swiftEmailAscii: true,
                    .swiftEmailAsciiUnicode: true,
                    .swiftEmailUnicode: true
                ]
            )
        )
    }
}
