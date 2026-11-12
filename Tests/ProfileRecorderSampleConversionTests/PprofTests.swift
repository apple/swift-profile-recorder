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
import ProfileRecorder
import ProfileRecorderPprofFormat
import _NIOFileSystem

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
        XCTAssertEqual(profile.sample[0].label.count, 3, "Should have thread_id, thread_name and thread_state labels")

        let nonZeroAddressLocations = profile.location.filter { $0.address != 0 }
        XCTAssertEqual(
            nonZeroAddressLocations.count,
            2,
            "Both valid instruction pointers should produce locations with addresses"
        )
    }

    func testPprofPeriodTypeFollowsSamplingMode() throws {
        let cases: [(ProfileRecorderSamplingMode?, String)] = [(nil, "wall"), (.wallTime, "wall"), (.cpuTime, "cpu")]
        for (mode, expected) in cases {
            var renderer = PprofOutputRenderer()
            let output = try renderer.finalise(
                sampleConfiguration: SampleConfig(
                    currentTimeSeconds: 0,
                    currentTimeNanoseconds: 0,
                    microSecondsBetweenSamples: 0,
                    sampleCount: 0,
                    mode: mode
                ),
                configuration: .default,
                symbolizer: self.symbolizer
            )
            let profile = try Perftools_Profiles_Profile(output)
            XCTAssertEqual(profile.stringTable[Int(profile.periodType.type)], expected)
            XCTAssertEqual(profile.stringTable[Int(profile.periodType.unit)], "nanoseconds")
        }
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
        XCTAssertEqual(sample.label.count, 3)

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

    // Samples that differ only in thread state stay separate pprof samples, each counted on its own.
    func testPprofSameStackSameThreadDifferentState_NotAggregated() throws {
        let profile = try self.renderPprof(
            ["running", "waiting", "running"].map { state in
                var header = SampleHeader(pid: 1, tid: 42, name: "worker", timeSec: 0, timeNSec: 0)
                header.state = state
                return header
            }
        )
        var valueByState: [String: [Int64]] = [:]
        for sample in profile.sample {
            let stateLabel = try XCTUnwrap(sample.label.first { profile.stringTable[Int($0.key)] == "thread_state" })
            valueByState[profile.stringTable[Int(stateLabel.str)]] = sample.value
        }
        XCTAssertEqual(valueByState, ["running": [2], "waiting": [1]])
    }

    // In a mixed profile, every sample gets a thread_state label; one without a state is labelled "unknown".
    func testPprofSampleWithoutStateIsLabelledUnknown() throws {
        var known = SampleHeader(pid: 1, tid: 1, name: "known", timeSec: 0, timeNSec: 0)
        known.state = "running"
        let profile = try self.renderPprof([
            known,
            SampleHeader(pid: 1, tid: 2, name: "missing", timeSec: 0, timeNSec: 0),
        ])
        var stateByThread: [String: String] = [:]
        for sample in profile.sample {
            let nameLabel = try XCTUnwrap(sample.label.first { profile.stringTable[Int($0.key)] == "thread_name" })
            let stateLabel = try XCTUnwrap(sample.label.first { profile.stringTable[Int($0.key)] == "thread_state" })
            XCTAssertEqual(sample.label.count, 3)
            stateByThread[profile.stringTable[Int(nameLabel.str)]] = profile.stringTable[Int(stateLabel.str)]
        }
        XCTAssertEqual(stateByThread, ["known": "running", "missing": "unknown"])
    }

    // End to end from raw sampler text to a pprof file: a SMPL record's "state" becomes a label, and a record
    // without one (written before the sampler recorded states) is labelled "unknown".
    func testRawFileRoundTripLabelsMissingStateUnknown() async throws {
        // The shape the sampler writes: the first STCK of each sample is the signal handler's frame and gets
        // dropped.
        let raw = """
            [SWIPR] VERS { "version": 1}
            [SWIPR] VMAP {"path": "/lib/libfoo.so", "architecture": "arm64", "segmentSlide": "0x1000", \
            "segmentStartAddress": "0x2000", "segmentEndAddress": "0x3000"}
            [SWIPR] CONF { "sampleCount": 1, "microSecondsBetweenSamples": 10000, "currentTimeSeconds": 1, \
            "currentTimeNanoseconds": 0, }
            [SWIPR] SMPL {"pid": 1, "tid": 10, "name": "runner", "timeSec": 1, "timeNSec": 0, "state": "running"}
            [SWIPR] STCK {"ip": "0x2100", "sp": "0x1"}
            [SWIPR] STCK {"ip": "0x2345", "sp": "0x1"}
            [SWIPR] DONE
            [SWIPR] SMPL {"pid": 1, "tid": 11, "name": "mystery", "timeSec": 1, "timeNSec": 0}
            [SWIPR] STCK {"ip": "0x2100", "sp": "0x1"}
            [SWIPR] STCK {"ip": "0x2345", "sp": "0x1"}
            [SWIPR] DONE

            """
        let profile = try await FileSystem.shared.withTemporaryDirectory { _, directory in
            let rawPath = directory.appending("samples.raw")
            let pprofPath = directory.appending("samples.pprof")
            try await raw.write(toFileAt: rawPath)

            let converter = ProfileRecorderSampleConverter(
                config: .default,
                renderer: PprofOutputRenderer(),
                symbolizer: FakeSymbolizer()
            )
            try await converter.convert(
                inputRawProfileRecorderFormatPath: rawPath.string,
                outputPath: pprofPath.string,
                format: .pprofSymbolized,
                logger: self.logger
            )
            return try Perftools_Profiles_Profile(
                try await ByteBuffer(contentsOf: pprofPath, maximumSizeAllowed: .mebibytes(32))
            )
        }
        XCTAssertEqual(profile.sample.count, 2)
        var stateByThread: [String: String] = [:]
        for sample in profile.sample {
            let nameLabel = try XCTUnwrap(sample.label.first { profile.stringTable[Int($0.key)] == "thread_name" })
            let stateLabel = try XCTUnwrap(sample.label.first { profile.stringTable[Int($0.key)] == "thread_state" })
            stateByThread[profile.stringTable[Int(nameLabel.str)]] = profile.stringTable[Int(stateLabel.str)]
        }
        XCTAssertEqual(stateByThread, ["runner": "running", "mystery": "unknown"])
    }

    private func renderPprof(_ headers: [SampleHeader]) throws -> Perftools_Profiles_Profile {
        var renderer = PprofOutputRenderer()
        for header in headers {
            let _ = try renderer.consumeSingleSample(
                Sample(
                    sampleHeader: header,
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
        return try Perftools_Profiles_Profile(output)
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
