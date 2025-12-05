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

public struct ProfileRecorderSampleConversionConfiguration: Sendable {
    public var includeFileLineInformation: Bool

    public static var `default`: ProfileRecorderSampleConversionConfiguration {
        return ProfileRecorderSampleConversionConfiguration(
            includeFileLineInformation: false
        )
    }
}

public protocol ProfileRecorderSampleConversionOutputRenderer: Sendable {
    @available(*, noasync, message: "blocks the calling thread")
    mutating func consumeSingleSample(
        _ sample: Sample,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> ByteBuffer

    @available(*, deprecated, renamed: "finalise(sampleConfiguration:sampleSummary:configuration:symbolizer:)")
    mutating func finalise(
        sampleConfiguration: SampleConfig,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> ByteBuffer

    mutating func finalise(
        sampleConfiguration: SampleConfig,
        sampleSummary: SampleSummary,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> ByteBuffer
}

extension ProfileRecorderSampleConversionOutputRenderer {
    @available(*, deprecated, renamed: "finalise(sampleConfiguration:sampleSummary:configuration:symbolizer:)")
    public mutating func finalise(
        sampleConfiguration: SampleConfig,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> ByteBuffer {
        return try self.finalise(
            sampleConfiguration: sampleConfiguration,
            sampleSummary: SampleSummary(sampleCount: sampleConfiguration.sampleCount ?? 0),
            configuration: configuration,
            symbolizer: symbolizer
        )
    }

    @available(
        *,
         deprecated,
         message: "You must implement finalise(sampleConfiguration:sampleSummary:configuration:symbolizer:)"
    )
    public mutating func finalise(
        sampleConfiguration: SampleConfig,
        sampleSummary: SampleSummary,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> ByteBuffer {
        return try self.finalise(
            sampleConfiguration: sampleConfiguration,
            configuration: configuration,
            symbolizer: symbolizer
        )
    }
}
