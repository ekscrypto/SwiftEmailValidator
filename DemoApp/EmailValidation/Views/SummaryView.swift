import SwiftUI

/// Main summary view showing all validation methods with their accuracy
struct SummaryView: View {
    @ObservedObject var store: TestDataStore

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.isLoading {
                    loadingView
                } else {
                    summarySection
                    methodsGrid
                    categoriesButton
                }
            }
            .padding()
        }
        .navigationTitle("Email Validators")
        .task {
            await store.loadAndValidate()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Running validation tests...")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("\(TestData.allTestCases.count) test cases")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comparing \(ValidationMethod.allCases.count) validation methods")
                .font(.headline)

            Text("\(store.testCases.count) test cases across \(TestCategory.allCases.count) categories")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var methodsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ValidationMethod.allCases) { method in
                NavigationLink(value: method) {
                    MethodSummaryCard(
                        method: method,
                        statistics: store.statistics(for: method)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var categoriesButton: some View {
        NavigationLink(value: "all-categories") {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                Text("View All Categories")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SummaryView(store: TestDataStore())
    }
}
