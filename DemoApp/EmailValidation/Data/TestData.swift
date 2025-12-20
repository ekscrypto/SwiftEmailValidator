import Foundation

/// Static test data extracted from SwiftEmailValidator unit tests
/// Organized by category for comparison across validation methods
struct TestData {

    /// All test cases combined
    static let allTestCases: [EmailTestCase] =
        validStandardCases +
        validSpecialCharsCases +
        validQuotedStringCases +
        validUnicodeCases +
        validIPLiteralCases +
        validRFC2047Cases +
        validBoundaryCases +
        missingAtSymbolCases +
        emptyLocalPartCases +
        leadingTrailingDotsCases +
        consecutiveDotsCases +
        invalidDotAtomCharsCases +
        invalidQuotedStringCases +
        invalidEscapeSequenceCases +
        localPartTooLongCases +
        invalidIPv4LiteralCases +
        invalidIPv6LiteralCases +
        ipv6ZoneIdentifierCases +
        unicodeInAsciiModeCases +
        controlCharacterCases +
        bidirectionalOverrideCases +
        invalidRFC2047Cases

    // MARK: - Valid Standard Email

    static let validStandardCases: [EmailTestCase] = [
        EmailTestCase(email: "user@site.com", category: .validStandard, expectedValid: true),
        EmailTestCase(email: "first.last@site.com", category: .validStandard, expectedValid: true),
        EmailTestCase(email: "a@site.com", category: .validStandard, expectedValid: true, description: "Single character local part"),
        EmailTestCase(email: "1@site.com", category: .validStandard, expectedValid: true, description: "Single digit local part"),
        EmailTestCase(email: "a.b.c@site.com", category: .validStandard, expectedValid: true),
        EmailTestCase(email: "a.b.c.d.e@site.com", category: .validStandard, expectedValid: true),
        EmailTestCase(email: "first.middle.last@site.com", category: .validStandard, expectedValid: true),
        EmailTestCase(email: "1.2.3@site.com", category: .validStandard, expectedValid: true, description: "Digits between dots"),
    ]

    // MARK: - Valid with Special Characters

    static let validSpecialCharsCases: [EmailTestCase] = [
        EmailTestCase(email: "!@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "#@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "$@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "%@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "&@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "'@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "*@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "+@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "-@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "/@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "=@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "?@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "^@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "_@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "`@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "{@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "|@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "}@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "~@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "first-@site.com", category: .validSpecialChars, expectedValid: true),
        EmailTestCase(email: "~.}.{._.^|.'+'.%!-.#&*.{u/=s3?r}`@site.com", category: .validSpecialChars, expectedValid: true, description: "Complex special char combination"),
        EmailTestCase(email: "!!@site.com", category: .validSpecialChars, expectedValid: true, description: "Consecutive !"),
        EmailTestCase(email: "##$$@site.com", category: .validSpecialChars, expectedValid: true, description: "Consecutive # and $"),
        EmailTestCase(email: "a+++b@site.com", category: .validSpecialChars, expectedValid: true, description: "Consecutive +"),
        EmailTestCase(email: "!user@site.com", category: .validSpecialChars, expectedValid: true, description: "! at start"),
        EmailTestCase(email: "user!@site.com", category: .validSpecialChars, expectedValid: true, description: "! at end"),
        EmailTestCase(email: "+user+@site.com", category: .validSpecialChars, expectedValid: true, description: "+ at both ends"),
    ]

    // MARK: - Valid Quoted Strings

    static let validQuotedStringCases: [EmailTestCase] = [
        EmailTestCase(email: #""email"@site.com"#, category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: #""Mickey Mouse"@disney.com"#, category: .validQuotedString, expectedValid: true, description: "Spaces in quoted string"),
        EmailTestCase(email: #"""@site.com"#, category: .validQuotedString, expectedValid: true, description: "Empty quoted string"),
        EmailTestCase(email: "\" \"@site.com", category: .validQuotedString, expectedValid: true, description: "Space only quoted string"),
        EmailTestCase(email: "\"!\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"#\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"$\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"%\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"&\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"'\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"(\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\")\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"*\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"+\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\",\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"-\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\".\"@site.com", category: .validQuotedString, expectedValid: true, description: "Dot in quoted string"),
        EmailTestCase(email: "\"/\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\":\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\";\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"<\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"=\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\">\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"?\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"@\"@site.com", category: .validQuotedString, expectedValid: true, description: "@ in quoted string"),
        EmailTestCase(email: "\"[\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"]\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"^\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"_\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"`\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"{\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"|\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"}\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: "\"~\"@site.com", category: .validQuotedString, expectedValid: true),
        EmailTestCase(email: #""\\"@site.com"#, category: .validQuotedString, expectedValid: true, description: "Escaped backslash"),
        EmailTestCase(email: #""\""@site.com"#, category: .validQuotedString, expectedValid: true, description: "Escaped quote"),
        EmailTestCase(email: #""email@notadomain.com"@site.com"#, category: .validQuotedString, expectedValid: true, description: "@ inside quotes"),
        EmailTestCase(email: #""user@fake@also"@site.com"#, category: .validQuotedString, expectedValid: true, description: "Multiple @ inside quotes"),
    ]

    // MARK: - Valid Unicode (Unicode mode only)

    static let validUnicodeCases: [EmailTestCase] = [
        EmailTestCase(email: "한@x.한국", category: .validUnicode, expectedValid: true, description: "Korean characters"),
        EmailTestCase(email: "한.భారత్@x.한국", category: .validUnicode, expectedValid: true, description: "Mixed Korean and Telugu"),
        EmailTestCase(email: "user😀@site.com", category: .validUnicode, expectedValid: true, description: "Emoji in local part"),
        EmailTestCase(email: "cafe\u{0301}@site.com", category: .validUnicode, expectedValid: true, description: "Combining mark (café)"),
        EmailTestCase(email: "\u{1D400}@site.com", category: .validUnicode, expectedValid: true, description: "Mathematical bold A (beyond BMP)"),
        EmailTestCase(email: String(repeating: "\u{1D11E}", count: 30) + "@site.com", category: .validUnicode, expectedValid: true, description: "30 musical symbols (4-byte chars)"),
        EmailTestCase(email: "한中あαбעعहবதతకಕമෆไᎠ@site.com", category: .validUnicode, expectedValid: true, description: "Diverse Unicode scripts"),
    ]

    // MARK: - Valid IP Address Literals

    static let validIPLiteralCases: [EmailTestCase] = [
        EmailTestCase(email: "Santa.Claus@[127.0.0.1]", category: .validIPLiteral, expectedValid: true, description: "IPv4 localhost"),
        EmailTestCase(email: "user@[0.0.0.0]", category: .validIPLiteral, expectedValid: true),
        EmailTestCase(email: "user@[255.255.255.255]", category: .validIPLiteral, expectedValid: true),
        EmailTestCase(email: "user@[192.168.2.1]", category: .validIPLiteral, expectedValid: true),
        EmailTestCase(email: "user@[10.0.3.57]", category: .validIPLiteral, expectedValid: true),
        EmailTestCase(email: "Santa.Claus@[IPv6:fe80::1]", category: .validIPLiteral, expectedValid: true, description: "IPv6 link-local"),
        EmailTestCase(email: "user@[IPv6:1:2:3:4:5:6:7:8]", category: .validIPLiteral, expectedValid: true, description: "Full IPv6"),
        EmailTestCase(email: "user@[IPv6:::1]", category: .validIPLiteral, expectedValid: true, description: "IPv6 loopback"),
        EmailTestCase(email: "user@[IPv6:ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff]", category: .validIPLiteral, expectedValid: true),
        EmailTestCase(email: "user@[IPv6:::ffff:192.168.1.1]", category: .validIPLiteral, expectedValid: true, description: "IPv4-mapped IPv6"),
    ]

    // MARK: - Valid RFC2047 Encoding

    static let validRFC2047Cases: [EmailTestCase] = [
        EmailTestCase(email: "=?iso-8859-1?q?\"Santa=20Claus\"@site.com?=", category: .validRFC2047, expectedValid: true, description: "Q-encoded quoted string"),
        EmailTestCase(email: "=?utf-8?B?7ZWcQHgu7ZWc6rWt?=", category: .validRFC2047, expectedValid: true, description: "B-encoded Korean"),
        EmailTestCase(email: "=?iso-8859-1?q?h=E9ro@cinema.ca?=", category: .validRFC2047, expectedValid: true, description: "Q-encoded Latin-1"),
    ]

    // MARK: - Valid Boundary Cases

    static let validBoundaryCases: [EmailTestCase] = [
        EmailTestCase(email: String(repeating: "x", count: 64) + "@site.com", category: .validBoundary, expectedValid: true, description: "Exactly 64-char local part (max)"),
        EmailTestCase(email: String(repeating: "x", count: 63) + "@site.com", category: .validBoundary, expectedValid: true, description: "63-char local part"),
    ]

    // MARK: - Missing @ Symbol

    static let missingAtSymbolCases: [EmailTestCase] = [
        EmailTestCase(email: "santa.claus", category: .missingAtSymbol, expectedValid: false),
        EmailTestCase(email: "\"santa.claus\"", category: .missingAtSymbol, expectedValid: false),
        EmailTestCase(email: "\"santa.claus\"northpole.com", category: .missingAtSymbol, expectedValid: false),
        EmailTestCase(email: "\"santa.claus@northpole.com", category: .missingAtSymbol, expectedValid: false, description: "Unclosed quote"),
    ]

    // MARK: - Empty Local Part

    static let emptyLocalPartCases: [EmailTestCase] = [
        EmailTestCase(email: "@site.com", category: .emptyLocalPart, expectedValid: false),
    ]

    // MARK: - Leading/Trailing Dots

    static let leadingTrailingDotsCases: [EmailTestCase] = [
        EmailTestCase(email: "user.@site.com", category: .leadingTrailingDots, expectedValid: false, description: "Trailing dot"),
        EmailTestCase(email: ".user@site.com", category: .leadingTrailingDots, expectedValid: false, description: "Leading dot"),
    ]

    // MARK: - Consecutive Dots

    static let consecutiveDotsCases: [EmailTestCase] = [
        EmailTestCase(email: "first..last@site.com", category: .consecutiveDots, expectedValid: false),
    ]

    // MARK: - Invalid Dot-Atom Characters

    static let invalidDotAtomCharsCases: [EmailTestCase] = [
        EmailTestCase(email: "\\user@site.com", category: .invalidDotAtomChars, expectedValid: false, description: "Backslash not allowed"),
        EmailTestCase(email: ":user@site.com", category: .invalidDotAtomChars, expectedValid: false, description: "Colon not allowed"),
        EmailTestCase(email: ":@site.com", category: .invalidDotAtomChars, expectedValid: false),
        EmailTestCase(email: ";@site.com", category: .invalidDotAtomChars, expectedValid: false, description: "Semicolon not allowed"),
        EmailTestCase(email: "u\"@site.com", category: .invalidDotAtomChars, expectedValid: false, description: "Unquoted double-quote"),
        EmailTestCase(email: "user.\"name\"@site.com", category: .invalidDotAtomChars, expectedValid: false, description: "Mixed dot-atom and quoted"),
    ]

    // MARK: - Invalid Quoted String

    static let invalidQuotedStringCases: [EmailTestCase] = [
        EmailTestCase(email: "\"\t\"@site.com", category: .invalidQuotedString, expectedValid: false, description: "Tab outside allowed range"),
        EmailTestCase(email: "\"Test\"\"@northpole.com", category: .invalidQuotedString, expectedValid: false, description: "Consecutive quotes"),
        EmailTestCase(email: "\"Test\"@\"northpole.com", category: .invalidQuotedString, expectedValid: false, description: "Quotes around domain"),
        EmailTestCase(email: "\"Test\".hello\"@northpole.com", category: .invalidQuotedString, expectedValid: false, description: "Mixed format"),
        EmailTestCase(email: #""email@notadomain.com""#, category: .invalidQuotedString, expectedValid: false, description: "No domain after quotes"),
    ]

    // MARK: - Invalid Escape Sequences

    static let invalidEscapeSequenceCases: [EmailTestCase] = [
        EmailTestCase(email: "\"test\\", category: .invalidEscapeSequence, expectedValid: false, description: "Incomplete escape"),
        EmailTestCase(email: #""\"@site.com"#, category: .invalidEscapeSequence, expectedValid: false, description: "Escape consumes closing quote"),
    ]

    // MARK: - Local Part Too Long

    static let localPartTooLongCases: [EmailTestCase] = [
        EmailTestCase(email: String(repeating: "x", count: 65) + "@site.com", category: .localPartTooLong, expectedValid: false, description: "65-char local part"),
        EmailTestCase(email: String(repeating: "x", count: 1000) + "@site.com", category: .localPartTooLong, expectedValid: false, description: "1000-char local part"),
        EmailTestCase(email: String(repeating: "한", count: 65) + "@site.com", category: .localPartTooLong, expectedValid: false, description: "65 Unicode chars"),
    ]

    // MARK: - Invalid IPv4 Literals

    static let invalidIPv4LiteralCases: [EmailTestCase] = [
        EmailTestCase(email: "Santa.Claus@[127.0.0.1", category: .invalidIPv4Literal, expectedValid: false, description: "Missing closing bracket"),
        EmailTestCase(email: "Santa.Claus@127.0.0.1", category: .invalidIPv4Literal, expectedValid: false, description: "Missing brackets"),
        EmailTestCase(email: "Santa.Claus@[127.0.0.1].com", category: .invalidIPv4Literal, expectedValid: false, description: "Extra .com after bracket"),
        EmailTestCase(email: "Santa.Claus@[127.0.0.1.]", category: .invalidIPv4Literal, expectedValid: false, description: "Trailing dot in IP"),
        EmailTestCase(email: "Santa.Claus@[.127.0.0.1]", category: .invalidIPv4Literal, expectedValid: false, description: "Leading dot in IP"),
        EmailTestCase(email: "Santa.Claus@[127:0:0:1]", category: .invalidIPv4Literal, expectedValid: false, description: "Colons instead of dots"),
        EmailTestCase(email: "user@[256.2.3.4]", category: .invalidIPv4Literal, expectedValid: false, description: "Octet > 255"),
        EmailTestCase(email: "user@[1.256.3.4]", category: .invalidIPv4Literal, expectedValid: false),
        EmailTestCase(email: "user@[1.2.256.4]", category: .invalidIPv4Literal, expectedValid: false),
        EmailTestCase(email: "user@[1.2.3.256]", category: .invalidIPv4Literal, expectedValid: false),
        EmailTestCase(email: "user@[0.0.0]", category: .invalidIPv4Literal, expectedValid: false, description: "Missing octet"),
    ]

    // MARK: - Invalid IPv6 Literals

    static let invalidIPv6LiteralCases: [EmailTestCase] = [
        EmailTestCase(email: "user@[IPv6:1:2:3:4:5:6:7:8:9]", category: .invalidIPv6Literal, expectedValid: false, description: "Too many segments"),
        EmailTestCase(email: "user@[IPv6:1:2:3:4:5:6::7:8]", category: .invalidIPv6Literal, expectedValid: false, description: "Multiple :: groups"),
        EmailTestCase(email: "user@[IPv6::1:2:3:4:5:6:7:8]", category: .invalidIPv6Literal, expectedValid: false, description: "Leading colon"),
        EmailTestCase(email: "user@[IPv6:1:2:3:4:5:6:7:8:]", category: .invalidIPv6Literal, expectedValid: false, description: "Trailing colon"),
        EmailTestCase(email: "user@[IPv6:1:2:3:4:5:6:7:88888]", category: .invalidIPv6Literal, expectedValid: false, description: "Segment too long"),
    ]

    // MARK: - IPv6 Zone Identifiers

    static let ipv6ZoneIdentifierCases: [EmailTestCase] = [
        EmailTestCase(email: "user@[IPv6:fe80::1%eth0]", category: .ipv6ZoneIdentifier, expectedValid: false, description: "Zone ID not allowed per RFC 5321"),
        EmailTestCase(email: "user@[IPv6:fe80::7:8%]", category: .ipv6ZoneIdentifier, expectedValid: false),
        EmailTestCase(email: "user@[IPv6:fe08::7:8i]", category: .ipv6ZoneIdentifier, expectedValid: false, description: "Invalid suffix"),
        EmailTestCase(email: "user@[IPv6:fe08::7:8interface]", category: .ipv6ZoneIdentifier, expectedValid: false),
    ]

    // MARK: - Unicode in ASCII Mode (invalid for ASCII, valid for Unicode mode)

    static let unicodeInAsciiModeCases: [EmailTestCase] = [
        EmailTestCase(email: "한@x.한국", category: .unicodeInAsciiMode, expectedValid: false, description: "Korean - valid in Unicode mode only",
                      expectedOverrides: [.swiftEmailUnicode: true]),
        EmailTestCase(email: "\"한\"@x.한국", category: .unicodeInAsciiMode, expectedValid: false, description: "Quoted Korean",
                      expectedOverrides: [.swiftEmailUnicode: true]),
        EmailTestCase(email: "user😀@site.com", category: .unicodeInAsciiMode, expectedValid: false, description: "Emoji - valid in Unicode mode only",
                      expectedOverrides: [.swiftEmailUnicode: true]),
        EmailTestCase(email: "cafe\u{0301}@site.com", category: .unicodeInAsciiMode, expectedValid: false, description: "Combining mark - valid in Unicode mode only",
                      expectedOverrides: [.swiftEmailUnicode: true]),
    ]

    // MARK: - Control Characters

    static let controlCharacterCases: [EmailTestCase] = [
        EmailTestCase(email: "test\u{0080}@site.com", category: .controlCharacters, expectedValid: false, description: "C1 control 0x80"),
        EmailTestCase(email: "test\u{0090}@site.com", category: .controlCharacters, expectedValid: false, description: "C1 control 0x90"),
        EmailTestCase(email: "test\u{009F}@site.com", category: .controlCharacters, expectedValid: false, description: "C1 control 0x9F"),
        EmailTestCase(email: "\nHello@this.com", category: .controlCharacters, expectedValid: false, description: "Newline character"),
    ]

    // MARK: - Bidirectional Override Characters

    static let bidirectionalOverrideCases: [EmailTestCase] = [
        EmailTestCase(email: "test\u{202E}@site.com", category: .bidirectionalOverride, expectedValid: false, description: "RTL override - security risk"),
        EmailTestCase(email: "test\u{202D}@site.com", category: .bidirectionalOverride, expectedValid: false, description: "LTR override"),
        EmailTestCase(email: "test\u{200E}@site.com", category: .bidirectionalOverride, expectedValid: false, description: "LTR mark"),
    ]

    // MARK: - Invalid RFC2047 Encoding

    static let invalidRFC2047Cases: [EmailTestCase] = [
        EmailTestCase(email: "=?schtroomf?b?shackalaka?=", category: .invalidRFC2047, expectedValid: false, description: "Unknown charset"),
        EmailTestCase(email: "=?iso-8859-1?r?h=E9ro@cinema.ca?=", category: .invalidRFC2047, expectedValid: false, description: "Invalid encoding letter R"),
        EmailTestCase(email: "=?iso-8859-1?q?h=E9ro@cinema.ca?", category: .invalidRFC2047, expectedValid: false, description: "Missing closing ="),
        EmailTestCase(email: "=?utf-8?B?7?=", category: .invalidRFC2047, expectedValid: false, description: "Invalid base64"),
        EmailTestCase(email: "=?iso-8859-1?q?1234567890123456789012345678901234567890123456789012345678901234567890@toolong.net?=", category: .invalidRFC2047, expectedValid: false, description: "Encoded value too long"),
    ]
}
