import Foundation

/// Email validator using Apple's NSDataDetector
/// This is Apple's recommended approach for email validation
struct NSDataDetectorValidator: Sendable {

    /// Validates an email using NSDataDetector's link detection
    /// Returns true if the entire string is detected as a mailto: link
    nonisolated static func validate(_ email: String) -> Bool {
        guard !email.isEmpty else { return false }

        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else {
            return false
        }

        let range = NSRange(email.startIndex..., in: email)
        let matches = detector.matches(in: email, options: [], range: range)

        // Check if any match is a mailto: link covering the entire string
        return matches.contains { match in
            match.url?.scheme == "mailto" && match.range == range
        }
    }
}
