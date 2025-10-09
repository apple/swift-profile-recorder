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

@testable import _ProfileRecorderSampleConversion

final class PprofTests: XCTestCase {
    private var symbolizer: CachedSymbolizer! = nil
    private var underlyingSymbolizer: (any Symbolizer)! = nil
    private var logger: Logger! = nil

    func testPprofBasic() throws {
        var renderer = PprofOutputRenderer()
        defer {
            var remainder: ByteBuffer?
            XCTAssertNoThrow(
                remainder = try renderer.finalise(
                    sampleConfiguration: SampleConfig(
                        currentTimeSeconds: 0,
                        currentTimeNanoseconds: 0,
                        microSecondsBetweenSamples: 0,
                        sampleCount: 0
                    ),
                    configuration: .default,
                    symbolizer: self.symbolizer
                )
            )
            XCTAssertNotEqual(ByteBuffer(string: ""), remainder)
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
                    StackFrame(instructionPointer: 0, stackPointer: .max), // this frame will be chopped
                    StackFrame(instructionPointer: 0x2345, stackPointer: .max),
                    StackFrame(instructionPointer: 0x2999, stackPointer: .max),
                ]
            ),
            configuration: .default,
            symbolizer: self.symbolizer
        )

        XCTAssertEqual(ByteBuffer(), actual)
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
                    architecture: "arm64",
                    segmentSlide: 0x1000,
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

    // MARK: - Helpers
    func instructionPointerFixup() -> Int {
        #if arch(arm) || arch(arm64)
        // Known fixed-width instruction format
        return 4
        #else
        // Unknown, subtract 1
        return 1
        #endif
    }
}
