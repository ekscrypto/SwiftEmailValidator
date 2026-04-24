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

# Run a single test class
swift test --filter EmailSyntaxValidatorTests

# Run a single test method
swift test --filter EmailSyntaxValidatorTests/testDotAtomLocalPart

# Run only UTS #39 companion-target tests
swift test --filter SwiftEmailValidatorUTS39Tests
```

## DemoApp

The `DemoApp/` directory contains a SwiftUI iOS app that compares email validation methods across ~150 test cases. Open `DemoApp/EmailValidation.xcodeproj` in Xcode to build and run on iOS Simulator.

## Benchmarks

`Benchmarks/` is a **separate SPM package** (not a target of the main `Package.swift`) so competitor dependencies do not leak into consumers. Run with `swift run -c release EmailBench` inside the directory; see `Benchmarks/README.md` for flags.

Its `Sources/EmailBench/TestData.swift` is a **symlink** to the canonical `DemoApp/EmailValidation/Data/TestData.swift` — edit only the DemoApp file; the Benchmarks side tracks automatically.

## Architecture Overview

SwiftEmailValidator is an RFC-compliant email syntax validator supporting international email addresses. It validates email format without requiring network access.

### Core Components

**EmailSyntaxValidator** (`Sources/SwiftEmailValidator/EmailSyntaxValidator.swift`)
- Main entry point with static methods: `correctlyFormatted()` and `mailbox()`
- Returns `Mailbox` struct containing parsed `localPart` (dotAtom or quotedString) and `host` (domain or addressLiteral)
- Supports three compatibility modes: `.ascii` (RFC822), `.asciiWithUnicodeExtension` (RFC2047), `.unicode` (RFC6531)
- Domain validation delegated to SwiftPublicSuffixList by default, customizable via `domainValidator` closure
- Local-part policy is pluggable via `localPartValidator: (String) -> Bool` closure (default `{ _ in true }`, added in 1.5.0). Receives the **semantic** local part — dot-atom as-is, quoted-string in cleaned (unescaped, unquoted) form. This is the hook the UTS #39 companion target plugs into.

**EmailNormalizer** (`Sources/SwiftEmailValidator/EmailNormalizer.swift`)
- Pure Unicode normalization helpers (`nfc(_:)`, `nfkc(_:)`), intentionally decoupled from the validator. `nfc` is RFC 6532 §3.1 compliant; `nfkc` is a documented deliberate deviation for Gmail-style anti-spoofing.
- Order matters: `nfkc` can expand length (e.g. `U+FDFA` → 18 scalars), so **always validate after normalizing, never the reverse**.

**RFC2047Coder** (`Sources/SwiftEmailValidator/RFC2047Coder.swift`)
- Encodes/decodes Unicode email addresses for ASCII-only systems
- Supports Base64 ('b') and Quoted-Printable ('q') encodings
- Handles utf-8, utf-16, utf-32, iso-8859-1, iso-8859-2 charsets

**IPAddressSyntaxValidator** (`Sources/SwiftEmailValidator/IPAddressSyntaxValidator.swift`)
- Validates IPv4 and IPv6 address literals in email hosts
- Used when `allowAddressLiteral: true` is passed to validation methods

**SwiftEmailValidatorUTS39** (`Sources/SwiftEmailValidatorUTS39/`)
- Opt-in companion library layering UTS #39 Unicode Security Mechanisms on top of the core validator
- Import separately (`import SwiftEmailValidatorUTS39`) to avoid bundling ~280 KB of Unicode data into callers that don't need it
- Provides `UTS39.Policy` with Identifier_Status filtering, mixed-script detection (Single/Highly/Moderately Restrictive), and §4 confusable skeletons
- Exposes `UTS39.localPartValidator(_:)` / `UTS39.domainValidator(_:)` factories plus convenience overloads `EmailSyntaxValidator.correctlyFormatted(_:uts39:)` / `mailbox(from:uts39:)`
- Plugs into the main validator through the `localPartValidator` closure parameter (added in 1.5.0)
- Data tables are generated from UCD via `Sources/SwiftEmailValidatorUTS39/Tools/generate.py`; regenerate only on UCD version upgrades

### Validation Flow

1. Optionally decode RFC2047 encoded input
2. Extract and validate local part (before @) — either dot-atom or quoted-string format
3. Run `localPartValidator` closure on the cleaned local part (UTS #39 policy plugs in here)
4. Extract host (after @) — either domain or address literal
5. Validate domain against Public Suffix List (or custom `domainValidator`)
6. Return structured `Mailbox` or `nil`

### Dependencies

- **SwiftPublicSuffixList** (>= 3.1.0): Domain validation against the Public Suffix List. Since PSL v3 rejects non-ASCII hostnames, the default `domainValidator` closure runs `PublicSuffixList.ace($0)` before `isUnrestricted(_:)`; `Mailbox.Host.domain(...)` still returns the original user-facing string (only the validator dispatch uses ACE).

### Key Design Decisions

- All public API methods are static - no instance creation needed
- Returns `nil` for invalid input rather than throwing
- Domain validation is pluggable via closure parameter
- Character validation uses pre-built `CharacterSet` instances for efficiency

### RFC / Unicode Standards Implemented

- RFC 822: Standard for the format of ARPA Internet text messages
- RFC 2047: MIME Part Three - Message header extensions for non-ASCII text
- RFC 5321: Simple Mail Transfer Protocol (SMTP)
- RFC 5322: Internet Message Format
- RFC 6531: SMTP Extension for Internationalized Email
- UTS #39: Unicode Security Mechanisms (via opt-in `SwiftEmailValidatorUTS39` target)
