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

import NIO
import PprofFormat
import SwiftProtobuf

public struct PprofOutputRenderer: ProfileRecorderSampleConversionOutputRenderer {
    var aggregator: SampleAggregator = SampleAggregator()

    public init() {}

    public mutating func consumeSingleSample(
        _ sample: Sample,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> ByteBuffer {
        let symbolisedStack = try sample.stack.map { frame in
            try symbolizer.symbolise(frame)
        }
        self.aggregator.add(symbolisedStack)
        return ByteBuffer()
    }

    public mutating func finalise(
        sampleConfiguration: SampleConfig,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> ByteBuffer {
        var stringTable: [String: StringWithID] = [:]
        for function in self.aggregator.functions.values {
            _ = stringTable.addAndGetID(function.name, type: StringWithID.self)
        }
        let samplesID = stringTable.addAndGetID("samples", type: StringWithID.self)
        let countID = stringTable.addAndGetID("count", type: StringWithID.self)
        let cpuID = stringTable.addAndGetID("cpu", type: StringWithID.self)
        let nanosecondsID = stringTable.addAndGetID("nanoseconds", type: StringWithID.self)

        let profile = Perftools_Profiles_Profile.with { profile in
            profile.location = self.aggregator.locations.values.sorted(by: { $0.id < $1.id }).map { location in
                .with {
                    $0.id = UInt64(location.id)
                    $0.line = location.functions.map { functionID in
                        .with {
                            $0.functionID = UInt64(functionID)
                        }
                    }
                }
            }
            profile.function = self.aggregator.functions.values.sorted(by: { $0.id < $1.id }).map { function in
                .with {
                    $0.id = UInt64(function.id)
                    $0.name = Int64(stringTable[function.name]!.id)
                }
            }
            profile.sampleType = [
                .with {
                    $0.type = Int64(samplesID)
                    $0.unit = Int64(countID)
                }
            ]
            profile.sample = self.aggregator.samples.map { (inSample, count) in
                Perftools_Profiles_Sample.with { outSample in
                    outSample.locationID = inSample.map { UInt64($0) }
                    outSample.value = [Int64(count)]
                }
            }
            profile.periodType = Perftools_Profiles_ValueType.with {
                $0.type = Int64(cpuID)
                $0.unit = Int64(nanosecondsID)
            }
            profile.timeNanos =
                (Int64(sampleConfiguration.currentTimeSeconds) * 1_000_000_000)
                + Int64(sampleConfiguration.currentTimeNanoseconds)
            profile.durationNanos =
                Int64(sampleConfiguration.sampleCount) * Int64(sampleConfiguration.microSecondsBetweenSamples) * 1_000
            profile.period = Int64(sampleConfiguration.microSecondsBetweenSamples) * 1_000

            /*
             we are symbolized already...
            profile.mapping = symbolizer.dynamicLibraryMappings.enumerated().map { (index, vmap) in
                .with {
                    $0.filename = Int64(stringTable.addAndGetID(vmap.path, type: StringWithID.self))
                    $0.id = UInt64(index + 1)
                    $0.memoryStart = UInt64(vmap.segmentStartAddress)
                    $0.memoryLimit = UInt64(vmap.segmentEndAddress)
                    $0.fileOffset = UInt64(vmap.segmentSlide)
                }
            }
             */
            profile.stringTable = [""] + stringTable.values.sorted(by: { $0.id < $1.id }).map { $0.value }
        }
        let output: ByteBufferForProto = try profile.serializedBytes()

        self.aggregator = SampleAggregator()
        return output.bytes
    }
}

struct StringWithID: HasID {
    var id: Int
    var value: String

    func updatingID(_ newID: Int) -> StringWithID {
        var new = self
        new.id = newID
        return new
    }
}

struct ByteBufferForProto: SwiftProtobufContiguousBytes {
    private(set) var bytes: ByteBuffer

    init(repeating: UInt8, count: Int) {
        self.bytes = ByteBuffer(repeating: repeating, count: count)
    }

    init<Bytes>(_ bytes: Bytes) where Bytes: Sequence, Bytes.Element == UInt8 {
        self.bytes = ByteBuffer(bytes: bytes)
    }

    var count: Int {
        return self.bytes.readableBytes
    }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        return try self.bytes.withUnsafeReadableBytes(body)
    }

    mutating func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
        return try self.bytes.withUnsafeMutableReadableBytes(body)
    }
}
