//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2021-2025 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

public struct FlamegraphCollapsedOutputRenderer: ProfileRecorderSampleConversionOutputRenderer {
    public init() {
    }

    public func consumeSingleSample(
        _ sample: Sample,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> NIOCore.ByteBuffer {
        var output = ByteBuffer()
        output.reserveCapacity(256 + sample.stack.count * 128)

        var first = true
        for stackFrame in sample.stack.reversed() {
            let framesIncludingInlinedFrames = try symbolizer.symbolise(stackFrame).allFrames.reversed()
            for frame in framesIncludingInlinedFrames {
                if !first {
                    output.writeString(";")
                }
                output.writeString("\(frame.functionName)<\(String(frame.address, radix: 16))>")

                first = false
            }
        }
        // Use ns as the weight
        output.writeString(" \(sample.timeSec * 1_000_000_000 +  sample.timeNSec)\n")

        return output
    }

    public func finalise(
        sampleConfiguration: SampleConfig,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) -> ByteBuffer {
        return ByteBuffer()
    }
}
