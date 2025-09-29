//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation

public struct Version: Decodable {
    public var version: Int
}

public struct Message: Decodable {
    public var message: String
    public var exit: CInt?
}

public struct SampleConfig: Codable & Hashable & Sendable {
    public init(
        currentTimeSeconds: Int,
        currentTimeNanoseconds: Int,
        microSecondsBetweenSamples: Int,
        sampleCount: Int
    ) {
        self.currentTimeSeconds = currentTimeSeconds
        self.currentTimeNanoseconds = currentTimeNanoseconds
        self.microSecondsBetweenSamples = microSecondsBetweenSamples
        self.sampleCount = sampleCount
    }
    public var currentTimeSeconds: Int
    public var currentTimeNanoseconds: Int
    public var microSecondsBetweenSamples: Int
    public var sampleCount: Int
}

public struct DynamicLibMapping: Decodable & Sendable & CustomStringConvertible & Hashable & Comparable {
    enum CodingKeys: CodingKey {
        case path
        case architecture
        case segmentSlide
        case segmentStartAddress
        case segmentEndAddress
    }
    public var path: String
    public var architecture: String
    public var segmentSlide: UInt
    public var segmentStartAddress: UInt
    public var segmentEndAddress: UInt

    public init(
        path: String,
        architecture: String,
        segmentSlide: UInt,
        segmentStartAddress: UInt,
        segmentEndAddress: UInt
    ) {
        self.path = path
        self.architecture = architecture
        self.segmentSlide = segmentSlide
        self.segmentStartAddress = segmentStartAddress
        self.segmentEndAddress = segmentEndAddress
    }

    public init(from decoder: Decoder) throws {
        struct FailedToDecodeAddressError: Error {}

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try container.decode(String.self, forKey: .path)
        self.architecture = try container.decode(String.self, forKey: .architecture)
        if let segmentSlide = UInt(try container.decode(String.self, forKey: .segmentSlide).dropFirst(2), radix: 16) {
            self.segmentSlide = segmentSlide
        } else {
            throw FailedToDecodeAddressError()
        }
        if let startAddress = UInt(
            try container.decode(String.self, forKey: .segmentStartAddress).dropFirst(2),
            radix: 16
        ) {
            self.segmentStartAddress = startAddress
        } else {
            throw FailedToDecodeAddressError()
        }
        if let endAddress = UInt(try container.decode(String.self, forKey: .segmentEndAddress).dropFirst(2), radix: 16)
        {
            self.segmentEndAddress = endAddress
        } else {
            throw FailedToDecodeAddressError()
        }
    }

    public static func < (lhs: DynamicLibMapping, rhs: DynamicLibMapping) -> Bool {
        return lhs.segmentStartAddress < rhs.segmentStartAddress
    }

    public var description: String {
        return """
            DynamicLibMapping {\
             path: '\(self.path)' (\(self.architecture)),\
             segmentSlide: 0x\(String(self.segmentSlide, radix: 16)),\
             segmentStart: 0x\(String(self.segmentStartAddress, radix: 16)),\
             segmentEnd: 0x\(String(self.segmentEndAddress, radix: 16))\
            }
            """
    }
}

public struct SampleHeader: Codable {
    public init(
        pid: Int,
        tid: Int,
        name: String,
        timeSec: Int,
        timeNSec: Int
    ) {
        self.pid = pid
        self.tid = tid
        self.name = name
        self.timeSec = timeSec
        self.timeNSec = timeNSec
    }
    var pid: Int
    var tid: Int
    var name: String
    var timeSec: Int
    var timeNSec: Int
}

public struct StackFrame: Codable & Sendable & CustomStringConvertible & Hashable {
    public enum CodingKeys: String, CodingKey {
        case instructionPointer = "ip"
        case stackPointer = "sp"
    }

    public var instructionPointer: UInt
    public var stackPointer: UInt

    public init(instructionPointer: UInt, stackPointer: UInt) {
        self.instructionPointer = instructionPointer
        self.stackPointer = stackPointer
    }

    public init(from decoder: Decoder) throws {
        struct FailedToDecodeAddressError: Error {}

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let ip = UInt(try container.decode(String.self, forKey: .instructionPointer).dropFirst(2), radix: 16) {
            self.instructionPointer = ip
        } else {
            throw FailedToDecodeAddressError()
        }
        if let sp = UInt(try container.decode(String.self, forKey: .stackPointer).dropFirst(2), radix: 16) {
            self.stackPointer = sp
        } else {
            throw FailedToDecodeAddressError()
        }
    }

    public var description: String {
        return """
            StackFrame {\
             ip: 0x\(String(self.instructionPointer, radix: 16)),\
             sp: 0x\(String(self.stackPointer, radix: 16))\
            }
            """
    }
}
