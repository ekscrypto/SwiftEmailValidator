# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-04-23

### Added

- **`IPAddressSyntaxValidator` public length-capped wrappers.** The public
  `match(_:)`, `matchIPv4(_:)`, and `matchIPv6(_:)` methods now apply a
  `utf8.count` guard before dispatching to the regex engine: 15 octets for
  IPv4 (max `255.255.255.255`), 45 octets for IPv6 (max
  `ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255`). Prior to this release
  these methods had no input-length bound, so a caller passing a
  multi-megabyte string would spend O(n) inside `NSRegularExpression`
  before the trailing `$` anchor failed — a potential denial-of-service
  vector for code paths that expose the validator to untrusted input
  directly (bypassing `EmailSyntaxValidator`, which already caps the
  whole address at 254 UTF-8 octets).
- **Internal raw matchers** `_match(_:)`, `_matchIPv4(_:)`, and
  `_matchIPv6(_:)` retain the pre-1.4.0 behaviour (no length guard) and
  are used by `EmailSyntaxValidator.extractHostLiteral` directly — the
  upstream address cap already bounds the input, so the hot path avoids
  a redundant second `utf8.count` check.
- **`Benchmarks/` SPM package.** A new standalone harness runs the
  195-case DemoApp corpus through every SPM-consumable Swift email
  validator we could locate (evanrobertson, MimeEmailParser, bdolewski's
  regex, jwelton-equivalent via `NSDataDetector`) and emits a Markdown
  accuracy table. Kept out of the main `Package.swift` so library
  consumers don't transitively pull the competitors. See the
  "Comparison with other Swift email validators" section in the README
  for the published results and the methodology.

### Security

- The length-capped public wrappers close the only input-length DoS
  vector found in a manual audit of the library's public API surface.
  `EmailSyntaxValidator` users were never exposed (it already caps the
  input upstream); the vector applied only to callers invoking
  `IPAddressSyntaxValidator` directly. No crashes were introduced;
  `EmailSyntaxValidator.correctlyFormatted(_:)` behaviour is unchanged.

## [1.3.1] - 2026-04-23

### Changed

- **SwiftPublicSuffixList dependency bumped to 3.1.0.** v3.0 tightened
  `PublicSuffixList.isUnrestricted(_:)` / `match(_:)` to reject non-ASCII
  hostnames — IDN labels must be in ACE (Punycode) form. The default
  `domainValidator` closure now calls `PublicSuffixList.ace(_:)` on the
  domain before dispatching to `isUnrestricted(_:)`, so Unicode IDN
  domains continue to validate exactly as they did on 1.3.0 with PSL 2.x.
- `Mailbox.Host.domain(...)` still carries the original user-facing
  string; only the validator dispatch uses the ACE form.

### Migration

Callers who pass a custom `domainValidator` closure to
`correctlyFormatted(_:)` / `mailbox(from:)` and rely on the PSL default
behavior via `PublicSuffixList.isUnrestricted(_:)` should wrap their call
site with `PublicSuffixList.ace(_:)` if the closure receives Unicode IDN
domains — e.g. `{ PublicSuffixList.isUnrestricted(PublicSuffixList.ace($0), rules: myRules) }`.

## [1.2.0] - 2026-04-22

### Security

This release consolidates a series of Unicode and RFC compliance fixes that
hardened the validator against spoofing, parser-confusion, and out-of-spec
inputs. Earlier 1.1.x versions accept characters and encoded sequences that
should be rejected; users should upgrade.

#### Unicode spoofing prevention (local part)

- **Zs-category space characters rejected.** U+00A0 (NO-BREAK SPACE),
  U+1680 (OGHAM SPACE MARK), U+2000–U+200A (EN QUAD … HAIR SPACE),
  U+202F (NARROW NO-BREAK SPACE), U+205F (MEDIUM MATHEMATICAL SPACE),
  U+3000 (IDEOGRAPHIC SPACE) are visually indistinguishable from U+0020 in
  most fonts and could be used to register lookalike accounts.
- **Reserved format character U+2065 rejected.** The previous block
  (U+2060–U+2064) left U+2065 reachable; the range is now U+2060–U+2065.
- **Plane 1–3 supplementary noncharacters rejected.** U+1FFFE/U+1FFFF,
  U+2FFFE/U+2FFFF, U+3FFFE/U+3FFFF (Unicode §23.7 permanently reserved
  noncharacters) are now blocked via explicit scalar guards.
- **Planes 4–13 (U+40000–U+DFFFF) rejected.** Entirely unassigned in
  Unicode; should never appear in interchange.
- **Full Supplementary Special-purpose Plane and Supplementary PUA
  rejected.** U+E0000–U+10FFFF blocked as a single guarded range, covering
  Tags, Variation Selectors Supplement, and Private Use Areas A/B.
- **Variation Selectors rejected.** U+FE00–U+FE0F are invisible combining
  characters that produce no glyph (same spoofing risk as ZWJ/ZWNJ).
- **U+FDD0–U+FDEF and U+FFFE/U+FFFF rejected.** BMP §23.7 permanently
  reserved noncharacters.

#### RFC 2047 decoder hardening

- **DEL (0x7F) rejected from Q-encoded content.** The prior
  `value >= 0x20` guard admitted 0x7F.
- **C1 control bytes (0x80–0x9F) rejected from Q-encoded ISO-8859-1/2
  content.** Previously decoded to U+0080–U+009F C1 controls, which RFC
  5198 §2 forbids in network interchange.
- **75-character encoded-word limit enforced** per RFC 2047 §2 (the prior
  limit allowed 76).
- **Underscore-as-space decoding** in Q encoding per RFC 2047 §4.2.

#### Quoted-string parser hardening

- **Per-scalar character-set check.** `extractQuotedString` now uses
  `unicodeScalars.allSatisfy` instead of `rangeOfCharacter` (which only
  inspected the first scalar of a grapheme cluster), preventing
  security-excluded scalars from slipping through as combining elements.
- **Escaped quoted-pair restricted to a single ASCII scalar** per RFC 5321
  (`quoted-pair = "\" (VCHAR / WSP)`).
- **Inline scalar guard** in `extractQuotedString` matches the dot-atom
  guard, ensuring identical security posture across both local-part forms.

#### IPv6 / address-literal hardening

- **Zone identifiers rejected** (e.g. `fe80::1%eth0`) per RFC 5321 §4.1.3.
- **Empty `IPv6:` literal, non-IPv6 strings after the `IPv6:` tag, and
  non-standard literal types (e.g. `[SMTP:…]`) are rejected**, with
  regression tests added.

### Fixed

- **CharacterSet construction order.** Foundation's `CharacterSet` has a
  bug where calling `.subtracting()` on a set containing supplementary
  Unicode planes corrupts the supplementary-plane bitmap. All exclusion
  sets are now subtracted before `supplementaryPlanes` is added via
  `.union()`. `unicodeNonCharacters`, `unicodeSpaceChars`, and
  `zeroWidthAndInvisibleChars` were updated to follow this rule.
- **Domain octet limits enforced** (RFC 1035 §2.3.4): per-label
  ≤63 octets, total domain ≤253 octets — measured in UTF-8 bytes, not
  character count.
- **Total email length enforced** at 254 UTF-8 bytes (RFC 5321 §4.5.3.1.3).
- **Quoted-string local part length enforced** at 64 UTF-8 bytes.
- **ASCII-only domain labels in `.ascii` mode.** Unicode U-labels are now
  rejected when `compatibility == .ascii`; Punycode (xn--…) labels remain
  accepted.
- **Source-route addresses rejected** (`@relay.host:user@domain`).
- **Empty host, double-`@`, empty domain labels, leading/trailing dots and
  hyphens in domain labels** are rejected regardless of the
  `domainValidator` closure.

### Documentation

- **`mailbox(from:)` and `correctlyFormatted(_:)` doc comments corrected.**
  Prior comments referenced a `strategy:` parameter and `ValidationStrategy`
  type that do not exist. Documentation now matches the actual `options:`
  parameter and `Options` enum.

### Tests

- Test count grew from 77 to 125 (all passing).
- New thematic coverage for: Zs space spoofing, supplementary
  noncharacters, Variation Selectors, the Unicode Tags block, source
  routes, address-literal edge cases, byte-vs-character length boundaries,
  RFC 2047 75-char limit and C1 rejection.

## [1.1.0] - 2025-12-19

### Added

#### DocC Documentation
- **EmailSyntaxValidator**: Class-level documentation with usage examples
- **Mailbox**: Struct and property documentation (`email`, `localPart`, `host`)
- **LocalPart/Host enums**: Case documentation for `dotAtom`, `quotedString`, `domain`, `addressLiteral`
- **Options enum**: Documentation for `autoEncodeToRfc2047` option
- **Compatibility enum**: Detailed documentation for `ascii`, `asciiWithUnicodeExtension`, `unicode` modes
- **RFC2047Coder**: Class documentation with encoding examples, `encode()` and `decode()` method documentation
- **IPAddressSyntaxValidator**: Class documentation explaining RFC 5321 context

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
