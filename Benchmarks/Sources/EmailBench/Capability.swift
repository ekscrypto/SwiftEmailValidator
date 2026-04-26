import Foundation

// What an email validator might claim to implement, broken into the
// individual specs / standards. A library is graded against a test case only
// if the case's required capability is one the library claims.
struct Capability: OptionSet, Hashable, Sendable {
    let rawValue: Int
    static let rfc5322       = Capability(rawValue: 1 << 0)  // dot-atom, quoted-string, basic alphabet
    static let rfc5321IPLit  = Capability(rawValue: 1 << 1)  // RFC 5321 IPv4/IPv6 address-literal grammar + 64-octet local-part cap
    static let rfc6531       = Capability(rawValue: 1 << 2)  // SMTPUTF8 — UTF-8 local-part / domain
    static let rfc2047       = Capability(rawValue: 1 << 3)  // encoded-word `=?charset?enc?text?=`
    static let domainPolicy  = Capability(rawValue: 1 << 4)  // IANA TLD list + RFC 6761/6762/7686/8375/9476 special-use
    static let unicodeHard   = Capability(rawValue: 1 << 5)  // UTS #39 / UAX #31 / RFC 6532 §3 hardening (bidi, default-ignorable, ZW, …)

    /// What a contemporary email-validation library should support to be
    /// considered RFC-current.
    static let modern: Capability = [.rfc5322, .rfc5321IPLit, .rfc6531, .rfc2047, .domainPolicy, .unicodeHard]
}

extension Capability {
    var displayList: [String] {
        var out: [String] = []
        if contains(.rfc5322)      { out.append("RFC 5322") }
        if contains(.rfc5321IPLit) { out.append("RFC 5321") }
        if contains(.rfc6531)      { out.append("RFC 6531") }
        if contains(.rfc2047)      { out.append("RFC 2047") }
        if contains(.domainPolicy) { out.append("RFC 6761/6762/7686/8375/9476 + IANA TLD") }
        if contains(.unicodeHard)  { out.append("UTS #39 / UAX #31 / RFC 6532 §3") }
        return out
    }
}

// Maps a corpus test case to the *strictest* capability needed to handle it
// correctly. Used to filter which cases are in a given adapter's declared
// scope. Cases requiring nothing beyond `.rfc5322` apply universally.
func requiredCapability(for c: EmailTestCase) -> Capability {
    switch c.category {
    case .missingAtSymbol, .emptyLocalPart, .leadingTrailingDots, .consecutiveDots,
         .invalidDotAtomChars, .invalidQuotedString, .invalidEscapeSequence,
         .invalidDomain,
         .validStandard, .validSpecialChars, .validQuotedString,
         .unicodeInAsciiMode:
        return .rfc5322

    case .localPartTooLong, .invalidIPv4Literal, .invalidIPv6Literal,
         .ipv6ZoneIdentifier, .validIPLiteral:
        return .rfc5321IPLit

    case .validUnicode:
        return .rfc6531

    case .validRFC2047, .invalidRFC2047, .rfc2047ControlInjection:
        return .rfc2047

    case .reservedSpecialUseDomain, .unknownTLD:
        return .domainPolicy

    case .validBoundary:
        // 63/64-char ASCII fits 5321; the 16 × U+1D11E case needs 6531.
        let isAscii = c.email.unicodeScalars.allSatisfy { $0.value < 0x80 }
        return isAscii ? .rfc5321IPLit : .rfc6531

    case .controlCharacters, .bidirectionalOverride, .unicodeNoncharacters,
         .zeroWidthInvisible, .unicodeSpaceSpoofing, .variationSelectors,
         .supplementaryDefaultIgnorable, .leadingCombiningMark,
         .tagCharacters, .supplementaryPlaneAttacks:
        return .unicodeHard
    }
}
