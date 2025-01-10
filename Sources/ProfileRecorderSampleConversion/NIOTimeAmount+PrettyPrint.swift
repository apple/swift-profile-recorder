//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2023-2024 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO

extension TimeAmount {
    init(_ userProvidedString: String, defaultUnit: String) throws {
        let string = String(userProvidedString.filter { !$0.isWhitespace }).lowercased()
        let parsedNumbers = string.prefix(while: { $0.isWholeNumber || $0.isPunctuation })
        let parsedUnit = string.dropFirst(parsedNumbers.count)

        guard let numbers = Int64(parsedNumbers) else {
            throw TimeAmountConversionError(message: "'\(userProvidedString)' cannot be parsed as number and unit")
        }
        let unit = parsedUnit.isEmpty ? defaultUnit : String(parsedUnit)

        switch unit {
        case "h", "hr":
            self = .hours(numbers)
        case "min":
            self = .minutes(numbers)
        case "s":
            self = .seconds(numbers)
        case "ms":
            self = .milliseconds(numbers)
        case "us":
            self = .microseconds(numbers)
        case "ns":
            self = .nanoseconds(numbers)
        default:
            throw TimeAmountConversionError(message: "Unknown unit '\(unit)' in '\(userProvidedString)")
        }
    }

    var prettyPrint: String {
        let fullNS = self.nanoseconds
        guard fullNS != 0 else {
            return "0ns"
        }
        let (fullUS, remUS) = fullNS.quotientAndRemainder(dividingBy: 1_000)
        let (fullMS, remMS) = fullNS.quotientAndRemainder(dividingBy: 1_000_000)
        let (fullS, remS) = fullNS.quotientAndRemainder(dividingBy: 1_000_000_000)

        if remS == 0 {
            return "\(fullS)s"
        } else if remMS == 0 {
            return "\(fullMS)ms"
        } else if remUS == 0 {
            return "\(fullUS)us"
        } else {
            return "\(fullNS)ns"
        }
    }
}

struct TimeAmountConversionError: Error {
    var message: String
}
