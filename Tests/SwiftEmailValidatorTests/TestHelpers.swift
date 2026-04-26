//
//  TestHelpers.swift
//  SwiftEmailValidator
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//

import Foundation

/// Test helper: accept any domain whose rightmost label is `com` and has
/// at least one non-empty preceding label. Replaces the legacy
/// `PublicSuffixList.isUnrestricted($0, rules: [["com"]])` pattern after
/// the dependency was removed in 1.6.0 — preserves the original test
/// isolation (no IANA-list lookup, no special-use blocklist).
let comOnlyDomainValidator: (String) -> Bool = { domain in
    let labels = domain.lowercased().split(separator: ".", omittingEmptySubsequences: false)
    return labels.count >= 2 && labels.allSatisfy { !$0.isEmpty } && labels.last == "com"
}
