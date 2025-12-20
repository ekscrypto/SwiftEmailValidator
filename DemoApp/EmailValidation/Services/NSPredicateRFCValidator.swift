import Foundation

/// Email validator using NSPredicate with an RFC 5322-like regex pattern
/// This is a common approach used by many iOS developers
struct NSPredicateRFCValidator: Sendable {

    /// Validates an email using NSPredicate with RFC-like regex
    /// Pattern allows: letters, digits, dots, underscores, percent, plus, minus in local part
    /// Requires: @ followed by domain with at least one dot
    /// TLD must be 2-64 characters (letters only)
    nonisolated static func validate(_ email: String) -> Bool {
        guard !email.isEmpty else { return false }

        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: email)
    }
}
