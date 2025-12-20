import SwiftUI

/// Card displaying summary statistics for a single validation method
struct MethodSummaryCard: View {
    let method: ValidationMethod
    let statistics: MethodStatistics

    private var accuracyColor: Color {
        if statistics.accuracy >= 0.95 {
            return .green
        } else if statistics.accuracy >= 0.80 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(method.shortName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if method.isNative {
                    Text("Native")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                } else {
                    Text("Library")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
            }

            Text(method.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            PassFailBar(pass: statistics.correctResults, fail: statistics.incorrectResults)

            HStack {
                Text("\(statistics.correctResults)/\(statistics.totalTests)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(statistics.accuracyPercentage)
                    .font(.headline)
                    .foregroundColor(accuracyColor)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

#Preview {
    VStack {
        MethodSummaryCard(
            method: .nsDataDetector,
            statistics: MethodStatistics(
                method: .nsDataDetector,
                totalTests: 240,
                correctResults: 180,
                truePositives: 90,
                trueNegatives: 90,
                falsePositives: 30,
                falseNegatives: 30
            )
        )

        MethodSummaryCard(
            method: .swiftEmailUnicode,
            statistics: MethodStatistics(
                method: .swiftEmailUnicode,
                totalTests: 240,
                correctResults: 235,
                truePositives: 118,
                trueNegatives: 117,
                falsePositives: 3,
                falseNegatives: 2
            )
        )
    }
    .padding()
}
