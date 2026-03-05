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
import ProfileRecorderPprofFormat

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

    func testPprofBasicDeserializesCorrectly() throws {
        var renderer = PprofOutputRenderer()
        let _ = try renderer.consumeSingleSample(
            Sample(
                sampleHeader: SampleHeader(pid: 1, tid: 2, name: "thread", timeSec: 4, timeNSec: 5),
                stack: [
                    StackFrame(instructionPointer: 0, stackPointer: .max),
                    StackFrame(instructionPointer: 0x2345, stackPointer: .max),
                    StackFrame(instructionPointer: 0x2999, stackPointer: .max),
                ]
            ),
            configuration: .default,
            symbolizer: self.symbolizer
        )
        let output = try renderer.finalise(
            sampleConfiguration: SampleConfig(
                currentTimeSeconds: 0,
                currentTimeNanoseconds: 0,
                microSecondsBetweenSamples: 0,
                sampleCount: 0
            ),
            configuration: .default,
            symbolizer: self.symbolizer
        )
        let profile = try Perftools_Profiles_Profile(output)
        XCTAssertEqual(profile.sample.count, 1)
        XCTAssertEqual(profile.sample[0].label.count, 2, "Should have thread_id and thread_name labels")
    }

    func testPprofSameStackDifferentThreads_NotAggregated() throws {
        var renderer = PprofOutputRenderer()
        for tid in [10, 20] {
            let _ = try renderer.consumeSingleSample(
                Sample(
                    sampleHeader: SampleHeader(pid: 1, tid: tid, name: "T\(tid)", timeSec: 0, timeNSec: 0),
                    stack: [
                        StackFrame(instructionPointer: 0x2345, stackPointer: .max)
                    ]
                ),
                configuration: .default,
                symbolizer: self.symbolizer
            )
        }
        let output = try renderer.finalise(
            sampleConfiguration: SampleConfig(
                currentTimeSeconds: 0,
                currentTimeNanoseconds: 0,
                microSecondsBetweenSamples: 0,
                sampleCount: 0
            ),
            configuration: .default,
            symbolizer: self.symbolizer
        )
        let profile = try Perftools_Profiles_Profile(output)
        XCTAssertEqual(profile.sample.count, 2, "Same stack from different threads should NOT be aggregated")
    }

    func testPprofSameStackSameThread_Aggregated() throws {
        var renderer = PprofOutputRenderer()
        for _ in 0..<3 {
            let _ = try renderer.consumeSingleSample(
                Sample(
                    sampleHeader: SampleHeader(pid: 1, tid: 42, name: "worker", timeSec: 0, timeNSec: 0),
                    stack: [
                        StackFrame(instructionPointer: 0x2345, stackPointer: .max)
                    ]
                ),
                configuration: .default,
                symbolizer: self.symbolizer
            )
        }
        let output = try renderer.finalise(
            sampleConfiguration: SampleConfig(
                currentTimeSeconds: 0,
                currentTimeNanoseconds: 0,
                microSecondsBetweenSamples: 0,
                sampleCount: 0
            ),
            configuration: .default,
            symbolizer: self.symbolizer
        )
        let profile = try Perftools_Profiles_Profile(output)
        XCTAssertEqual(profile.sample.count, 1, "Same stack from same thread should be aggregated")
        XCTAssertEqual(profile.sample[0].value, [3])
    }

    func testPprofHasCorrectThreadLabels() throws {
        var renderer = PprofOutputRenderer()
        let _ = try renderer.consumeSingleSample(
            Sample(
                sampleHeader: SampleHeader(pid: 1, tid: 42, name: "main-thread", timeSec: 0, timeNSec: 0),
                stack: [
                    StackFrame(instructionPointer: 0x2345, stackPointer: .max)
                ]
            ),
            configuration: .default,
            symbolizer: self.symbolizer
        )
        let output = try renderer.finalise(
            sampleConfiguration: SampleConfig(
                currentTimeSeconds: 0,
                currentTimeNanoseconds: 0,
                microSecondsBetweenSamples: 0,
                sampleCount: 0
            ),
            configuration: .default,
            symbolizer: self.symbolizer
        )
        let profile = try Perftools_Profiles_Profile(output)
        XCTAssertEqual(profile.sample.count, 1)

        let sample = profile.sample[0]
        XCTAssertEqual(sample.label.count, 2)

        let threadIDLabel = sample.label.first { profile.stringTable[Int($0.key)] == "thread_id" }
        XCTAssertNotNil(threadIDLabel)
        XCTAssertEqual(threadIDLabel?.num, 42)

        let threadNameLabel = sample.label.first { profile.stringTable[Int($0.key)] == "thread_name" }
        XCTAssertNotNil(threadNameLabel)
        XCTAssertEqual(profile.stringTable[Int(threadNameLabel!.str)], "main-thread")
    }

    func testPprofThreadNameStringTableLookupIsSafe() throws {
        var renderer = PprofOutputRenderer()
        let threadNames = ["", "NIO-ELT-0-#3", "worker-pool-7"]
        for (index, name) in threadNames.enumerated() {
            let _ = try renderer.consumeSingleSample(
                Sample(
                    sampleHeader: SampleHeader(
                        pid: 1,
                        tid: index + 1,
                        name: name,
                        timeSec: 0,
                        timeNSec: 0
                    ),
                    stack: [
                        StackFrame(instructionPointer: 0x2345, stackPointer: .max)
                    ]
                ),
                configuration: .default,
                symbolizer: self.symbolizer
            )
        }
        let output = try renderer.finalise(
            sampleConfiguration: SampleConfig(
                currentTimeSeconds: 0,
                currentTimeNanoseconds: 0,
                microSecondsBetweenSamples: 0,
                sampleCount: 0
            ),
            configuration: .default,
            symbolizer: self.symbolizer
        )
        let profile = try Perftools_Profiles_Profile(output)
        XCTAssertEqual(profile.sample.count, 3)
        let emittedNames = Set(
            profile.sample.compactMap { sample -> String? in
                let label = sample.label.first { profile.stringTable[Int($0.key)] == "thread_name" }
                return label.map { profile.stringTable[Int($0.str)] }
            }
        )
        XCTAssertEqual(emittedNames, Set(threadNames))
    }

    // MARK: - Setup/teardown
    override func setUpWithError() throws {
        self.logger = Logger(label: "\(Self.self)")
        self.logger.logLevel = .info

        self.underlyingSymbolizer = FakeSymbolizer()
        try self.underlyingSymbolizer!.start()
        self.symbolizer = CachedSymbolizer(
            configuration: .default,
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
