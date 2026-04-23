import Foundation

// NSDataDetector baseline — functionally identical to jwelton/EmailValidator,
// which is a thin wrapper around NSDataDetector's `.link` check. Included here
// so the grid can report a score for the jwelton approach without pulling a
// second dependency that collides with evanrobertson/EmailValidator on the
// package identity "EmailValidator".
enum JweltonEquivalentAdapter: ValidatorAdapter {
    static let name = "jwelton/EmailValidator (via NSDataDetector)"
    static let link = "https://github.com/jwelton/EmailValidator"
    static let rfcCoverage = "Apple NSDataDetector (unspecified)"
    static let pslIntegration = false
    static let referenceMethod: ValidationMethod = .nsDataDetector

    private static let detector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    static func validate(_ email: String) -> Bool {
        guard !email.isEmpty, let detector else { return false }
        let range = NSRange(email.startIndex..., in: email)
        let matches = detector.matches(in: email, options: [], range: range)
        return matches.contains { $0.url?.scheme == "mailto" && $0.range == range }
    }
}
