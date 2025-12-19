# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### New Unit Tests (48 tests across 3 files)

**EmailSyntaxValidatorTests.swift**
- `testLocalPartExactly63Characters` - Boundary test for 63-character local part
- `testLocalPartExactlyOneCharacter` - Minimum valid local part
- `testLocalPartEmptyString` - Empty local part rejection
- `testUnicodeLocalPartCharacterVsByteCount` - 30 four-byte Unicode chars (120 bytes, 30 chars)
- `testUnicodeLocalPartExceeds64Characters` - 65+ Unicode character rejection
- `testEmojiInLocalPart` - Emoji validation in Unicode mode
- `testCombiningMarksInLocalPart` - Diacritics and combining characters
- `testHighUnicodeRanges` - Characters beyond BMP (U+1D400+)
- `testZeroWidthCharacters` - ZWSP, ZWJ, ZWNJ handling
- `testBidirectionalOverrideCharacters` - RTL/LTR control character rejection
- `testC1ControlCharactersRejected` - C1 control character rejection (U+0080-U+009F)
- `testRFC2047EncodedWithIPv4AddressLiteral` - RFC2047 with IPv4 literal
- `testRFC2047EncodedWithIPv6AddressLiteral` - RFC2047 with IPv6 literal
- `testQuotedStringWithMultipleAtSymbols` - Multiple @ in quoted strings
- `testQuotedStringWithRFC2047Decoding` - RFC2047 decoded quoted strings
- `testAutoEncodeToRfc2047WithAddressLiteral` - Combined options testing
- `testCustomDomainValidatorAcceptsAnyDomain` - Permissive validator
- `testCustomDomainValidatorRejectsAllDomains` - Restrictive validator
- `testCustomDomainValidatorWithSpecificTLDs` - TLD-specific validation
- `testCustomDomainValidatorReceivesCorrectDomain` - Domain parameter verification
- `testCustomDomainValidatorWithUnicodeDomain` - IDN domain handling
- `testMultipleDotsInVariousPositions` - Valid multi-dot local parts
- `testSingleCharactersBetweenDots` - Minimal segments between dots
- `testMaxConsecutiveSpecialCharacters` - Consecutive special characters
- `testSpecialCharactersAtBoundaries` - Special chars at start/end of segments
- `testExtremelyLongLocalPart` - 1000 character local part rejection
- `testExtremelyLongDomain` - 500+ character domain handling
- `testVeryLongRFC2047EncodedString` - Near 76-char limit RFC2047
- `testManyUnicodeCharactersInLocalPart` - 64 diverse Unicode characters

**RFC2047CoderTests.swift**
- `testDecodingUTF16B` - Base64 with UTF-16 charset
- `testDecodingUTF32B` - Base64 with UTF-32 charset
- `testDecodingUTF16InvalidData` - Malformed UTF-16 rejection
- `testDecodingUTF32InvalidData` - Malformed UTF-32 rejection
- `testEncodeDecodeRoundTripSimpleASCII` - ASCII round-trip
- `testEncodeDecodeRoundTripUnicode` - Unicode round-trip
- `testEncodeDecodeRoundTripSpecialCharacters` - Special character round-trip
- `testDecodingLatin2QPolishCharacters` - Polish special characters
- `testDecodingLatin2QCzechCharacters` - Czech special characters
- `testDecodingLatin2InvalidControlCharacter` - Invalid byte handling
- `testEncodeEmptyString` - Empty string encoding
- `testDecodeWithMixedCaseCharset` - Case-insensitive charset
- `testDecodeWithMixedCaseEncoding` - Case-insensitive encoding type
- `testDecodeWithWhitespaceInEncodedWord` - Whitespace handling

**IPAddressValidatorTests.swift**
- `testIPv6ZoneIdentifiers` - Zone identifier rejection per RFC 5321
- `testIPv6LoopbackVariants` - `::1` variations
- `testIPv4MappedIPv6Extended` - `::ffff:` mapped addresses
- `testIPv4LeadingZeros` - Leading zeros handling
- `testEmptyIPAddressStrings` - Empty/whitespace rejection

### Changed

- **EmailSyntaxValidator.swift**: Reordered CharacterSet construction to work around Foundation bug where `.subtracting()` corrupts supplementary Unicode plane data. Supplementary planes (U+10000-U+10FFFF) are now added last, after all subtractions.

### Fixed

#### RFC 5321 Compliance
- **IPAddressSyntaxValidator.swift**: IPv6 zone identifiers (e.g., `fe80::1%eth0`) are now correctly rejected. Per RFC 5321 Section 4.1.3, zone identifiers are not valid in email address literals.

#### RFC 5198 Compliance
- **EmailSyntaxValidator.swift**: C1 control characters (U+0080-U+009F) are now rejected in Unicode mode. Per RFC 5198 Section 2, these control characters should be avoided in network interchange.

#### RFC 6531 Compliance
- **EmailSyntaxValidator.swift**: Fixed supplementary Unicode plane support (U+10000-U+10FFFF). Emoji, mathematical symbols, and other characters beyond the Basic Multilingual Plane now correctly validate in Unicode mode.

#### Security Improvements
- **EmailSyntaxValidator.swift**: Bidirectional formatting characters are now rejected:
  - Left-to-Right Mark / Right-to-Left Mark (U+200E-U+200F)
  - Directional embeddings and overrides (U+202A-U+202E)
  - Directional isolates (U+2066-U+2069)
  - Deprecated format characters (U+206A-U+206F)

  These characters can be exploited for homograph attacks and email spoofing.

### Technical Notes

#### CharacterSet Bug Workaround
Foundation's `CharacterSet` has a bug where calling `.subtracting()` on a set that includes supplementary Unicode planes (U+10000+) corrupts the supplementary plane data, even when the subtracted characters don't overlap. The workaround is to add supplementary planes as the final `.union()` call, after all `.subtracting()` operations are complete.

```swift
// WRONG - supplementary planes get corrupted by subsequent subtractions
let charset = baseSet
    .union(supplementaryPlanes)  // Added here...
    .subtracting(c1Controls)     // ...corrupted here

// CORRECT - add supplementary planes last
let charset = baseSet
    .subtracting(c1Controls)     // All subtractions first
    .union(supplementaryPlanes)  // Add supplementary planes last
```
