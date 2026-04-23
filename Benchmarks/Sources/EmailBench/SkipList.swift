import Foundation

// Per-adapter skip list. Each entry records an input that causes the library
// under test to invoke Swift's `fatalError` (e.g. a string-index out-of-bounds
// deep inside its parser). `fatalError` cannot be caught in-process, so these
// inputs are omitted from that library's accuracy denominator and surfaced
// separately in the report.
//
// To refresh this list after a corpus change, run the discovery loop:
//
//   swift build -c release
//   for a in OursAscii OursAsciiUnicode OursUnicode \
//            EvanRobertsonAscii EvanRobertsonInternational \
//            MimeParser Bdolewski JweltonEquivalent; do
//     start=0
//     while ! .build/arm64-apple-macosx/release/EmailBench \
//                --worker "$a" --start "$start" 2>/dev/null \
//             | tee /tmp/w.log | grep -q '"kind":"done"'; do
//       start=$(($(grep '"kind":"begin"' /tmp/w.log | tail -1 \
//                   | sed -E 's/.*"idx":([0-9]+).*/\1/') + 1))
//     done
//   done
enum SkipList {
    struct Entry { let email: String; let reason: String }

    static let entries: [String: [Entry]] = [
        "OursAscii":        [],
        "OursAsciiUnicode": [],
        "OursUnicode":      [],
        "EvanRobertsonAscii": [
            Entry(email: "user@[0.0.0]",
                  reason: "library indexes past end while scanning incomplete IPv4 literal"),
            Entry(email: "user@[IPv6:]",
                  reason: "library indexes past end on empty IPv6 literal"),
        ],
        "EvanRobertsonInternational": [
            Entry(email: "한.భారత్@x.한국",
                  reason: "fatalError on international local part (valid RFC 6531 case)"),
            Entry(email: String(repeating: "\u{1D11E}", count: 16) + "@site.com",
                  reason: "fatalError on 16 supplementary-plane musical-symbol scalars"),
            Entry(email: String(repeating: "\u{1D11E}", count: 30) + "@site.com",
                  reason: "fatalError on 30 supplementary-plane musical-symbol scalars"),
            Entry(email: "user@[0.0.0]",
                  reason: "library indexes past end while scanning incomplete IPv4 literal"),
            Entry(email: "user@[IPv6:]",
                  reason: "library indexes past end on empty IPv6 literal"),
        ],
        "MimeParser": [
            Entry(email: "=?schtroomf?b?shackalaka?=",
                  reason: "fatalError decoding invalid base64 inside RFC 2047 encoded-word"),
            Entry(email: "=?utf-8?B?7?=",
                  reason: "fatalError decoding truncated base64 inside RFC 2047 encoded-word"),
        ],
        "Bdolewski":        [],
        "JweltonEquivalent": [],
    ]
}
