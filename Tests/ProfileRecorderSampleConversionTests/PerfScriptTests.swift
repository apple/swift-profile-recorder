//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import XCTest
import NIO

@testable import ProfileRecorderSampleConversion

final class PerfScriptTests: XCTestCase {
    private var symbolizer: CachedSymbolizer! = nil
    private var underlyingSymbolizer: (any Symbolizer)! = nil
    private var logger: Logger! = nil

    func testPerfScriptNumberRenderingSmallNumber() throws {
        let renderer = PerfScriptOutputRenderer()
        defer {
            let remainder = renderer.finalise(
                sampleConfiguration: SampleConfig(
                    currentTimeSeconds: 0,
                    currentTimeNanoseconds: 0,
                    microSecondsBetweenSamples: 0,
                    sampleCount: 0
                ),
                configuration: .default,
                symbolizer: self.symbolizer
            )
            XCTAssertEqual(ByteBuffer(string: ""), remainder)
        }
        let actual = try renderer.consumeSingleSample(
            Sample(
                sampleHeader: SampleHeader(
                    pid: 1,
                    tid: 2,
                    name: "thread",
                    timeSec: 4,
                    timeNSec: 5 // important, this is a small number, so it'll get 0 prefixed
                ),
                stack: [
                    StackFrame(instructionPointer: 0x2345, stackPointer: .max),
                    StackFrame(instructionPointer: 0x2999, stackPointer: .max),
                ]
            ),
            configuration: .default,
            symbolizer: self.symbolizer
        )

        let expected = """
                       thread-T2     1/2     4.000000005:    swipr
                       \t    1345 fake+0x5 (libfoo)
                       \t    1999 fake+0x5 (libfoo)


                       """
        XCTAssertEqual(expected, String(buffer: actual))
    }

    func testPerfScriptNumberRenderingLargeNumber() throws {
        let renderer = PerfScriptOutputRenderer()
        defer {
            let remainder = renderer.finalise(
                sampleConfiguration: SampleConfig(
                    currentTimeSeconds: 0,
                    currentTimeNanoseconds: 0,
                    microSecondsBetweenSamples: 0,
                    sampleCount: 0
                ),
                configuration: .default,
                symbolizer: self.symbolizer
            )
            XCTAssertEqual(ByteBuffer(string: ""), remainder)
        }
        let actual = try renderer.consumeSingleSample(
            Sample(
                sampleHeader: SampleHeader(
                    pid: 1,
                    tid: 2,
                    name: "thread",
                    timeSec: 4,
                    timeNSec: 987_654_321 // important, this is a large number, no zero prefixes
                ),
                stack: [
                    StackFrame(instructionPointer: 0x2345, stackPointer: .max),
                    StackFrame(instructionPointer: 0x2999, stackPointer: .max),
                ]
            ),
            configuration: .default,
            symbolizer: self.symbolizer
        )

        let expected = """
                       thread-T2     1/2     4.987654321:    swipr
                       \t    1345 fake+0x5 (libfoo)
                       \t    1999 fake+0x5 (libfoo)


                       """
        XCTAssertEqual(expected, String(buffer: actual))
    }

    // MARK: - Setup/teardown
    override func setUpWithError() throws {
        self.logger = Logger(label: "\(Self.self)")
        self.logger.logLevel = .info

        self.underlyingSymbolizer = FakeSymbolizer()
        try self.underlyingSymbolizer!.start()
        self.symbolizer = CachedSymbolizer(
            configuration: SymbolizerConfiguration(perfScriptOutputWithFileLineInformation: false),
            symbolizer: self.underlyingSymbolizer!,
            dynamicLibraryMappings: [
                DynamicLibMapping(
                    path: "/lib/libfoo.so",
                    fileMappedAddress: 0x1000,
                    segmentStartAddress: 0x2000,
                    segmentEndAddress: 0x3000
                )
            ],
            group: .singletonMultiThreadedEventLoopGroup,
            logger: self.logger
        )
    }

    override func tearDown() {
        XCTAssertNoThrow(try self.underlyingSymbolizer!.shutdown())
        self.underlyingSymbolizer = nil
        self.symbolizer = nil
        self.logger = nil
    }
}
