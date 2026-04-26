//
//  Punycode.swift
//  SwiftEmailValidatorIDNA
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  RFC 3492 Punycode encoder/decoder.
//  https://datatracker.ietf.org/doc/html/rfc3492
//
//  Used by UTS #46 ToASCII / ToUnicode for encoding U-labels to A-labels
//  (`xn--…` form) and decoding back.
//

import Foundation

enum Punycode {

    // MARK: - RFC 3492 §5 parameters (Bootstring for Punycode)

    private static let base: UInt32 = 36
    private static let tmin: UInt32 = 1
    private static let tmax: UInt32 = 26
    private static let skew: UInt32 = 38
    private static let damp: UInt32 = 700
    private static let initialBias: UInt32 = 72
    private static let initialN: UInt32 = 128
    private static let delimiter: Character = "-"

    /// RFC 3492 §6.3 encode. Returns the Punycode-encoded body of `input`
    /// (without the `xn--` ACE prefix). Returns `nil` on overflow.
    static func encode(_ input: String) -> String? {
        let scalars = Array(input.unicodeScalars.map { $0.value })
        var output = ""

        // Copy basic (ASCII) code points to the output, in order.
        var basicCount = 0
        for v in scalars where v < 0x80 {
            output.append(Character(Unicode.Scalar(v)!))
            basicCount += 1
        }
        let h0 = basicCount
        if basicCount > 0 {
            output.append(delimiter)
        }

        var n: UInt32 = initialN
        var delta: UInt32 = 0
        var bias: UInt32 = initialBias
        var h: UInt32 = UInt32(h0)
        let total: UInt32 = UInt32(scalars.count)

        while h < total {
            // Find the smallest non-basic code point >= n.
            var m: UInt32 = .max
            for v in scalars where v >= n && v < m {
                m = v
            }
            // delta += (m - n) * (h + 1) — overflow guard.
            let mn = m &- n
            let h1 = h &+ 1
            let inc = mn.multipliedReportingOverflow(by: h1)
            if inc.overflow { return nil }
            let newDelta = delta.addingReportingOverflow(inc.partialValue)
            if newDelta.overflow { return nil }
            delta = newDelta.partialValue
            n = m

            for v in scalars {
                if v < n {
                    let inc = delta.addingReportingOverflow(1)
                    if inc.overflow { return nil }
                    delta = inc.partialValue
                }
                if v == n {
                    var q = delta
                    var k: UInt32 = base
                    while true {
                        let t: UInt32
                        if k <= bias { t = tmin }
                        else if k >= bias + tmax { t = tmax }
                        else { t = k - bias }
                        if q < t { break }
                        let digit = t + (q - t) % (base - t)
                        output.append(digitToBasic(digit))
                        q = (q - t) / (base - t)
                        k += base
                    }
                    output.append(digitToBasic(q))
                    bias = adapt(delta, h + 1, h == UInt32(h0))
                    delta = 0
                    h += 1
                }
            }
            delta += 1
            n += 1
        }

        return output
    }

    /// RFC 3492 §6.2 decode. `input` is the body of an `xn--…` label
    /// (the `xn--` prefix already stripped). Returns the decoded U-label,
    /// or `nil` on malformed input.
    static func decode(_ input: String) -> String? {
        var output: [UInt32] = []

        // Locate the last delimiter (separator between basic and extended parts).
        let chars = Array(input)
        let delimIndex = chars.lastIndex(of: delimiter)

        let basicEnd = delimIndex ?? -1
        if basicEnd >= 0 {
            for i in 0..<basicEnd {
                let c = chars[i]
                guard let s = c.asciiValue, s < 0x80 else { return nil }
                output.append(UInt32(s))
            }
        }

        var i: UInt32 = 0
        var n: UInt32 = initialN
        var bias: UInt32 = initialBias
        var pos = basicEnd >= 0 ? basicEnd + 1 : 0

        while pos < chars.count {
            let oldI = i
            var w: UInt32 = 1
            var k: UInt32 = base
            while true {
                if pos >= chars.count { return nil }
                let c = chars[pos]
                pos += 1
                guard let digit = basicToDigit(c) else { return nil }
                let mul = digit.multipliedReportingOverflow(by: w)
                if mul.overflow { return nil }
                let add = i.addingReportingOverflow(mul.partialValue)
                if add.overflow { return nil }
                i = add.partialValue

                let t: UInt32
                if k <= bias { t = tmin }
                else if k >= bias + tmax { t = tmax }
                else { t = k - bias }
                if digit < t { break }
                let baseMinusT = base - t
                let mul2 = w.multipliedReportingOverflow(by: baseMinusT)
                if mul2.overflow { return nil }
                w = mul2.partialValue
                k += base
            }
            let outLen = UInt32(output.count + 1)
            bias = adapt(i - oldI, outLen, oldI == 0)
            let nAdd = n.addingReportingOverflow(i / outLen)
            if nAdd.overflow { return nil }
            n = nAdd.partialValue
            i = i % outLen

            // Forbidden code points.
            if n < 0x80 { return nil }
            // Surrogates and out-of-range scalars.
            if (n >= 0xD800 && n <= 0xDFFF) || n > 0x10FFFF { return nil }

            output.insert(n, at: Int(i))
            i += 1
        }

        // Reassemble as a String.
        var result = ""
        result.reserveCapacity(output.count)
        for v in output {
            guard let scalar = Unicode.Scalar(v) else { return nil }
            result.append(Character(scalar))
        }
        return result
    }

    // MARK: - RFC 3492 §6.1 bias adaptation

    private static func adapt(_ delta: UInt32, _ numpoints: UInt32, _ firstTime: Bool) -> UInt32 {
        var d = firstTime ? delta / damp : delta / 2
        d += d / numpoints
        var k: UInt32 = 0
        while d > ((base - tmin) * tmax) / 2 {
            d /= base - tmin
            k += base
        }
        return k + (((base - tmin + 1) * d) / (d + skew))
    }

    // MARK: - RFC 3492 §5 digit alphabet

    /// Map digit value 0-35 to its basic-code-point representation
    /// (a-z = 0-25, 0-9 = 26-35), all lowercase.
    private static func digitToBasic(_ d: UInt32) -> Character {
        if d < 26 {
            return Character(Unicode.Scalar(UInt8(d) + 0x61))  // 'a'
        } else {
            return Character(Unicode.Scalar(UInt8(d - 26) + 0x30))  // '0'
        }
    }

    /// Map a basic code point back to its digit value, or nil if not a digit.
    /// Case-insensitive on letters.
    private static func basicToDigit(_ c: Character) -> UInt32? {
        guard let ascii = c.asciiValue else { return nil }
        if ascii >= 0x30 && ascii <= 0x39 { return UInt32(ascii) - 0x30 + 26 }  // 0-9
        if ascii >= 0x41 && ascii <= 0x5A { return UInt32(ascii) - 0x41 }       // A-Z
        if ascii >= 0x61 && ascii <= 0x7A { return UInt32(ascii) - 0x61 }       // a-z
        return nil
    }
}
