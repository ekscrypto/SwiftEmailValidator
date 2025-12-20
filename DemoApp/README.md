# Email Validator Demo App

A SwiftUI iOS app that compares email validation methods by running ~150 test cases against native iOS validators and the SwiftEmailValidator library.

## Validation Methods Compared

### Native iOS Methods
1. **NSDataDetector** - Apple's recommended approach using link detection
2. **NSPredicate (RFC 5322)** - Common regex pattern used by developers
3. **NSPredicate (Simple)** - Basic regex pattern commonly found online

### SwiftEmailValidator Modes
4. **ASCII mode** - Strict RFC 822 compliance
5. **ASCII + Unicode** - RFC 2047 support for encoded Unicode
6. **Unicode mode** - Full RFC 6531 international email support

## Test Categories

The app tests emails across 23 categories:

**Invalid Email Types:**
- Missing @ symbol
- Empty local part
- Leading/trailing dots
- Consecutive dots
- Invalid dot-atom characters
- Invalid quoted strings
- Invalid escape sequences
- Local part too long (>64 chars)
- Invalid IPv4/IPv6 literals
- IPv6 zone identifiers
- Unicode in ASCII mode
- Control characters
- Bidirectional override characters
- Invalid RFC2047 encoding

**Valid Email Types:**
- Standard emails
- Special characters
- Quoted strings
- Unicode (international)
- IP address literals
- RFC2047 encoded
- Boundary cases (63-64 char local parts)

## Running the App

### Option 1: Xcode Project (Recommended for iOS)

1. Open Xcode
2. Create a new iOS App project
3. Add package dependency: File > Add Package Dependencies
4. Add local package at: `../` (parent SwiftEmailValidator directory)
5. Copy the source files from `EmailValidatorDemo/Sources/` into your project

### Option 2: Swift Package (macOS/Catalyst)

```bash
cd DemoApp/EmailValidatorDemo
swift build
```

## Project Structure

```
EmailValidatorDemo/
├── Sources/
│   ├── App/
│   │   ├── EmailValidatorDemoApp.swift
│   │   └── ContentView.swift
│   ├── Models/
│   │   ├── EmailTestCase.swift
│   │   ├── TestCategory.swift
│   │   ├── ValidationMethod.swift
│   │   ├── ValidationResult.swift
│   │   └── TestDataStore.swift
│   ├── Services/
│   │   ├── NSDataDetectorValidator.swift
│   │   ├── NSPredicateRFCValidator.swift
│   │   ├── NSPredicateSimpleValidator.swift
│   │   ├── SwiftEmailValidatorWrapper.swift
│   │   └── ValidationService.swift
│   ├── Views/
│   │   ├── SummaryView.swift
│   │   ├── CategoryListView.swift
│   │   ├── CategoryDetailView.swift
│   │   ├── TestCaseDetailView.swift
│   │   └── Components/
│   │       ├── MethodSummaryCard.swift
│   │       ├── PassFailBar.swift
│   │       └── ValidationResultBadge.swift
│   └── Data/
│       └── TestData.swift
└── Package.swift
```

## Expected Results

The demo app demonstrates that native iOS validation methods have limitations compared to RFC-compliant validators:

- **NSDataDetector**: Misses quoted strings, IP literals, RFC2047 encoding
- **NSPredicate (RFC)**: Rejects valid special characters (!#$%&'*/=?^_`{|}~)
- **NSPredicate (Simple)**: Accepts many invalid patterns
- **SwiftEmailValidator**: Full RFC compliance across all test cases
