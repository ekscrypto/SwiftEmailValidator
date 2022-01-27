//
//  Base64Padder.swift
//  SwiftEmailValidator
//
//  Created by Dave Poirier on 2022-01-27.
//

import Foundation

struct Base64Padder {
    static func pad(_ value: String) -> String {
        var padded = value
        while padded.count % 4 != 0 {
            padded += "="
        }
        return padded
    }
}
