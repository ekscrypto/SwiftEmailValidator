import Foundation
import SwiftEmailValidator

/// Wrapper for SwiftEmailValidator library providing three compatibility modes
struct SwiftEmailValidatorWrapper: Sendable {

    /// Validates using ASCII mode (RFC 822 strict)
    /// - Only ASCII characters allowed
    /// - No Unicode support
    nonisolated static func validateAscii(_ email: String, allowAddressLiteral: Bool = true) -> Bool {
        EmailSyntaxValidator.correctlyFormatted(
            email,
            compatibility: .ascii,
            allowAddressLiteral: allowAddressLiteral
        )
    }

    /// Validates using ASCII with Unicode Extension mode (RFC 2047)
    /// - ASCII characters required
    /// - Unicode can be RFC 2047 encoded
    nonisolated static func validateAsciiWithUnicode(_ email: String, allowAddressLiteral: Bool = true) -> Bool {
        EmailSyntaxValidator.correctlyFormatted(
            email,
            compatibility: .asciiWithUnicodeExtension,
            allowAddressLiteral: allowAddressLiteral
        )
    }

    /// Validates using full Unicode mode (RFC 6531)
    /// - Full international email address support
    /// - Unicode characters allowed in local part and domain
    nonisolated static func validateUnicode(_ email: String, allowAddressLiteral: Bool = true) -> Bool {
        EmailSyntaxValidator.correctlyFormatted(
            email,
            compatibility: .unicode,
            allowAddressLiteral: allowAddressLiteral
        )
    }
}
