# EmailBench — competitor comparison harness

A standalone Swift Package that runs SwiftEmailValidator's 195-case DemoApp
corpus against a set of other Swift email validation libraries and prints a
Markdown-formatted accuracy table.

Kept separate from the main `Package.swift` so consumers of
`SwiftEmailValidator` don't transitively pull competitor dependencies.

## Libraries under test

| Key                          | Library                                                                 |
|------------------------------|-------------------------------------------------------------------------|
| `OursAscii`                  | SwiftEmailValidator — `.ascii` mode                                     |
| `OursAsciiUnicode`           | SwiftEmailValidator — `.asciiWithUnicodeExtension` mode                 |
| `OursUnicode`                | SwiftEmailValidator — `.unicode` mode                                   |
| `EvanRobertsonAscii`         | [evanrobertson/EmailValidator](https://github.com/evanrobertson/EmailValidator) — `allowInternational: false` |
| `EvanRobertsonInternational` | evanrobertson/EmailValidator — `allowInternational: true`               |
| `MimeParser`                 | [igorrendulic/MimeEmailParser](https://github.com/igorrendulic/MimeEmailParser) |
| `Bdolewski`                  | [bdolewski/SwiftEmailValidator](https://github.com/bdolewski/SwiftEmailValidator) — regex vendored (their symbol is `internal` and can't be imported) |
| `JweltonEquivalent`          | [jwelton/EmailValidator](https://github.com/jwelton/EmailValidator) — emulated via `NSDataDetector` to avoid a package-identity collision with evanrobertson's `EmailValidator` |

Deliberately excluded:

- **swift-standards/swift-emailaddress-standard** — its manifest uses
  `.package(path: "../../swift-ietf/…")` and requires macOS 26; it isn't
  consumable as a Git SPM dependency.
- **SwiftValidator / SwiftValidators / adamwaite/Validator** — general-purpose
  form validators, not RFC-focused email parsers.

## Running

```bash
cd Benchmarks
swift run -c release EmailBench              # print the table
swift run -c release EmailBench --verbose    # also list every failing case
```

## Skip list

Some competitors call `fatalError` on adversarial inputs (out-of-bounds string
indexing in their own parsers). Swift's `fatalError` can't be caught inside
the same process, so those inputs are listed in
[`Sources/EmailBench/SkipList.swift`](Sources/EmailBench/SkipList.swift) and
omitted from the library's accuracy denominator. The report surfaces the skip
count and the reason in a separate section.

To re-discover crashers (e.g. after adding new corpus cases) use the worker
mode:

```bash
swift build -c release
for a in OursAscii OursAsciiUnicode OursUnicode \
         EvanRobertsonAscii EvanRobertsonInternational \
         MimeParser Bdolewski JweltonEquivalent; do
  start=0
  while : ; do
    .build/arm64-apple-macosx/release/EmailBench \
      --worker "$a" --start "$start" 2>/dev/null > /tmp/w.log || true
    grep -q '"kind":"done"' /tmp/w.log && break
    crash=$(grep '"kind":"begin"' /tmp/w.log | tail -1 \
              | sed -E 's/.*"idx":([0-9]+).*/\1/')
    echo "$a crashed at idx $crash"
    start=$((crash + 1))
  done
done
```

Use `--list` to map indices back to email strings.
