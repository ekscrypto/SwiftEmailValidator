import SwiftUI

/// List of all test categories with their results
struct CategoryListView: View {
    @ObservedObject var store: TestDataStore
    let filterMethod: ValidationMethod?

    var body: some View {
        List {
            if let method = filterMethod {
                Section {
                    Text("Showing categories where \(method.rawValue) had incorrect results")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Invalid Email Categories") {
                ForEach(TestCategory.invalidCategories) { category in
                    let results = store.results(for: category)
                    if shouldShow(category: category, results: results) {
                        NavigationLink(value: category) {
                            CategoryRow(
                                category: category,
                                results: results,
                                store: store
                            )
                        }
                    }
                }
            }

            Section("Valid Email Categories") {
                ForEach(TestCategory.validCategories) { category in
                    let results = store.results(for: category)
                    if shouldShow(category: category, results: results) {
                        NavigationLink(value: category) {
                            CategoryRow(
                                category: category,
                                results: results,
                                store: store
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(filterMethod?.shortName ?? "Categories")
    }

    private func shouldShow(category: TestCategory, results: [ValidationResult]) -> Bool {
        guard !results.isEmpty else { return false }
        guard let method = filterMethod else { return true }
        // Only show categories where this method had errors
        return results.contains { !$0.isCorrect(for: method) }
    }
}

/// Row for a single category
struct CategoryRow: View {
    let category: TestCategory
    let results: [ValidationResult]
    let store: TestDataStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(category.isValidCategory ? .green : .red)

                Text(category.rawValue)
                    .font(.headline)
            }

            Text("\(results.count) test cases")
                .font(.caption)
                .foregroundColor(.secondary)

            // Mini accuracy row for each method
            HStack(spacing: 4) {
                ForEach(ValidationMethod.allCases) { method in
                    let accuracy = store.accuracy(for: method, in: category)
                    MethodAccuracyPill(method: method, accuracy: accuracy)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Small pill showing method accuracy
struct MethodAccuracyPill: View {
    let method: ValidationMethod
    let accuracy: Double

    private var color: Color {
        if accuracy >= 0.95 { return .green }
        if accuracy >= 0.80 { return .orange }
        return .red
    }

    var body: some View {
        Text(method.shortName.prefix(1))
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(color)
            .clipShape(Circle())
    }
}

#Preview {
    NavigationStack {
        CategoryListView(store: TestDataStore(), filterMethod: nil)
    }
}
