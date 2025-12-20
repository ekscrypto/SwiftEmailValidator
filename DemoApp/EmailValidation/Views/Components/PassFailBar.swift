import SwiftUI

/// Horizontal bar showing pass/fail ratio with color gradient
struct PassFailBar: View {
    let pass: Int
    let fail: Int

    private var total: Int { pass + fail }
    private var passRatio: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(pass) / CGFloat(total)
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geometry.size.width * passRatio)

                Rectangle()
                    .fill(Color.red)
                    .frame(width: geometry.size.width * (1 - passRatio))
            }
        }
        .frame(height: 8)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    VStack(spacing: 20) {
        PassFailBar(pass: 80, fail: 20)
        PassFailBar(pass: 50, fail: 50)
        PassFailBar(pass: 10, fail: 90)
        PassFailBar(pass: 100, fail: 0)
        PassFailBar(pass: 0, fail: 100)
    }
    .padding()
}
