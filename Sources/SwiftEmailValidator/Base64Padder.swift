//
//  Base64Padder.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-27.
//

import Foundation

internal struct Base64Padder {
    static func pad(_ value: String) -> String {
        let padding: [String] = ["", "===", "==", "="]
        return "\(value)\(padding[value.count % 4])"
    }
}
