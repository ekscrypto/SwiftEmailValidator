import SwiftUI

/// Small badge showing validation result for a single method
struct ValidationResultBadge: View {
    let isCorrect: Bool
    let method: ValidationMethod

    var body: some View {
        Circle()
            .fill(isCorrect ? Color.green : Color.red)
            .frame(width: 16, height: 16)
            .overlay(
                Text(String(method.shortName.prefix(1)))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}

/// Row of badges for all validation methods
struct ValidationBadgeRow: View {
    let result: ValidationResult

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ValidationMethod.allCases) { method in
                ValidationResultBadge(
                    isCorrect: result.isCorrect(for: method),
                    method: method
                )
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            ValidationResultBadge(isCorrect: true, method: .nsDataDetector)
            ValidationResultBadge(isCorrect: false, method: .nsPredicateRFC)
            ValidationResultBadge(isCorrect: true, method: .swiftEmailUnicode)
        }
    }
    .padding()
}
