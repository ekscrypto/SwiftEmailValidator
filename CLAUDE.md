# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build the package
swift build

# Run all tests
swift test

# Run tests with code coverage
swift test --enable-code-coverage
```

## Architecture Overview

SwiftEmailValidator is an RFC-compliant email syntax validator supporting international email addresses. It validates email format without requiring network access.

### Core Components

**EmailSyntaxValidator** (`Sources/SwiftEmailValidator/EmailSyntaxValidator.swift`)
- Main entry point with static methods: `correctlyFormatted()` and `mailbox()`
- Returns `Mailbox` struct containing parsed `localPart` (dotAtom or quotedString) and `host` (domain or addressLiteral)
- Supports three compatibility modes: `.ascii` (RFC822), `.asciiWithUnicodeExtension` (RFC2047), `.unicode` (RFC6531)
- Domain validation delegated to SwiftPublicSuffixList by default, customizable via `domainValidator` closure

**RFC2047Coder** (`Sources/SwiftEmailValidator/RFC2047Coder.swift`)
- Encodes/decodes Unicode email addresses for ASCII-only systems
- Supports Base64 ('b') and Quoted-Printable ('q') encodings
- Handles utf-8, utf-16, utf-32, iso-8859-1, iso-8859-2 charsets

**IPAddressSyntaxValidator** (`Sources/SwiftEmailValidator/IPAddressSyntaxValidator.swift`)
- Validates IPv4 and IPv6 address literals in email hosts
- Used when `allowAddressLiteral: true` is passed to validation methods

### Validation Flow

1. Optionally decode RFC2047 encoded input
2. Extract and validate local part (before @) - either dot-atom or quoted-string format
3. Extract host (after @) - either domain or address literal
4. Validate domain against Public Suffix List (or custom validator)
5. Return structured `Mailbox` or `nil`

### Dependencies

- **SwiftPublicSuffixList**: Domain validation against the Public Suffix List. First use incurs 100-900ms initialization delay.

### Key Design Decisions

- All public API methods are static - no instance creation needed
- Returns `nil` for invalid input rather than throwing
- Domain validation is pluggable via closure parameter
- Character validation uses pre-built `CharacterSet` instances for efficiency
