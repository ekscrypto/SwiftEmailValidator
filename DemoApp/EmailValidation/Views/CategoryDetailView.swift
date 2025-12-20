import SwiftUI

/// Detail view for a single category showing all test cases
struct CategoryDetailView: View {
    @ObservedObject var store: TestDataStore
    let category: TestCategory

    private var results: [ValidationResult] {
        store.results(for: category)
    }

    var body: some View {
        List {
            headerSection
            testCasesSection
        }
        .navigationTitle(category.rawValue)
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundColor(category.isValidCategory ? .green : .red)

                    Text("Expected: \(category.isValidCategory ? "Valid" : "Invalid")")
                        .font(.headline)
                }

                Text("\(results.count) test cases in this category")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                methodAccuracyGrid
            }
        }
    }

    private var methodAccuracyGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Method Accuracy")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(ValidationMethod.allCases) { method in
                let correct = results.filter { $0.isCorrect(for: method) }.count
                let accuracy = store.accuracy(for: method, in: category)

                HStack {
                    Text(method.shortName)
                        .font(.caption)
                        .frame(width: 60, alignment: .leading)

                    PassFailBar(pass: correct, fail: results.count - correct)

                    Text("\(correct)/\(results.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)

                    Text(String(format: "%.0f%%", accuracy * 100))
                        .font(.caption.bold())
                        .foregroundColor(accuracy >= 0.95 ? .green : (accuracy >= 0.80 ? .orange : .red))
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    private var testCasesSection: some View {
        Section("Test Cases") {
            ForEach(results) { result in
                NavigationLink(value: result) {
                    TestCaseRow(result: result)
                }
            }
        }
    }
}

/// Row for a single test case
struct TestCaseRow: View {
    let result: ValidationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.testCase.displayEmail)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)

            if let description = result.testCase.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ValidationBadgeRow(result: result)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(store: TestDataStore(), category: .validQuotedString)
    }
}
