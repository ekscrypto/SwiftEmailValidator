import Foundation

// Each adapter is reachable by a short key for the worker-subprocess
// crash-discovery path. See `runDiscovery` in main.swift.
let adapterRegistry: [String: (name: String, validate: (String) -> Bool, referenceMethod: ValidationMethod)] = [
    "OursAscii":                  (OursAscii.name, OursAscii.validate, OursAscii.referenceMethod),
    "OursAsciiUnicode":           (OursAsciiUnicode.name, OursAsciiUnicode.validate, OursAsciiUnicode.referenceMethod),
    "OursUnicode":                (OursUnicode.name, OursUnicode.validate, OursUnicode.referenceMethod),
    "EvanRobertsonAscii":         (EvanRobertsonAscii.name, EvanRobertsonAscii.validate, EvanRobertsonAscii.referenceMethod),
    "EvanRobertsonInternational": (EvanRobertsonInternational.name, EvanRobertsonInternational.validate, EvanRobertsonInternational.referenceMethod),
    "MimeParser":                 (MimeParserAdapter.name, MimeParserAdapter.validate, MimeParserAdapter.referenceMethod),
    "Bdolewski":                  (BdolewskiAdapter.name, BdolewskiAdapter.validate, BdolewskiAdapter.referenceMethod),
    "JweltonEquivalent":          (JweltonEquivalentAdapter.name, JweltonEquivalentAdapter.validate, JweltonEquivalentAdapter.referenceMethod),
]

let orderedAdapterKeys: [String] = [
    "OursAscii", "OursAsciiUnicode", "OursUnicode",
    "EvanRobertsonAscii", "EvanRobertsonInternational",
    "MimeParser", "Bdolewski", "JweltonEquivalent",
]

// Worker mode: run one adapter starting at the given index and flush a begin
// line before each validate() call and a result line after. If the process
// aborts mid-case, the driver can see the last begin idx to identify the
// crasher.
func runWorker(adapterKey: String, startIndex: Int) -> Never {
    guard let adapter = adapterRegistry[adapterKey] else {
        FileHandle.standardError.write(Data("unknown adapter: \(adapterKey)\n".utf8))
        exit(2)
    }
    let cases = TestData.allTestCases
    let stdout = FileHandle.standardOutput
    for idx in startIndex..<cases.count {
        let c = cases[idx]
        stdout.write(Data("{\"kind\":\"begin\",\"idx\":\(idx)}\n".utf8))
        try? stdout.synchronize()
        let got = adapter.validate(c.email)
        let expected = c.expectedResult(for: adapter.referenceMethod)
        stdout.write(Data("{\"kind\":\"result\",\"idx\":\(idx),\"got\":\(got),\"expected\":\(expected)}\n".utf8))
        try? stdout.synchronize()
    }
    stdout.write(Data("{\"kind\":\"done\"}\n".utf8))
    exit(0)
}
