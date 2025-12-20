import Foundation

/// Email validator using NSPredicate with a simple regex pattern
/// This represents the most basic regex patterns commonly found online
struct NSPredicateSimpleValidator: Sendable {

    /// Validates an email using NSPredicate with simple regex
    /// Pattern: anything @ anything . anything
    /// This is intentionally permissive to show what basic validation catches
    nonisolated static func validate(_ email: String) -> Bool {
        guard !email.isEmpty else { return false }

        let pattern = #"^.+@.+\..+$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: email)
    }
}
