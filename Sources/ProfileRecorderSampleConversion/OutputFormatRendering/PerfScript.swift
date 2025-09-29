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

import NIO

public struct PerfScriptOutputRenderer: ProfileRecorderSampleConversionOutputRenderer {
    public init() {}

    func formatSecAndNSec(sec: Int, nsec: Int) -> String {
        var nSecString = "\(nsec)"
        let missingDigits = 9 - nSecString.count
        if missingDigits > 0 {
            nSecString.insert(contentsOf: String(repeating: "0", count: missingDigits), at: nSecString.startIndex)
        }
        return "\(sec).\(nSecString)"
    }

    public func consumeSingleSample(
        _ sample: Sample,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> ByteBuffer {
        var output = ByteBuffer()
        output.reserveCapacity(256 + sample.stack.count * 128)

        output.writeString(
            """
            \(sample.threadName)-T\(sample.tid)     \
            \(sample.pid)/\(sample.tid)     \
            \(formatSecAndNSec(sec: sample.timeSec, nsec: sample.timeNSec)):    \
            swipr

            """
        )
        for stackFrame in sample.stack {
            let framesIncludingInlinedFrames = try symbolizer.symbolise(stackFrame).allFrames
            let hasMultiple = framesIncludingInlinedFrames.count > 1
            for index in framesIncludingInlinedFrames.indices {
                let symbolicatedFrame = framesIncludingInlinedFrames[index]
                let isLast = index == framesIncludingInlinedFrames.endIndex - 1

                output.writeString(
                    """
                    \t    \
                    \(String(symbolicatedFrame.address, radix: 16)) \
                    \(symbolicatedFrame.functionName)\(hasMultiple && !isLast ? " [inlined]" :"")\
                    +0x\(String(symbolicatedFrame.functionOffset, radix: 16)) \
                    (\(symbolicatedFrame.library))

                    """
                )
                if configuration.includeFileLineInformation,
                    let file = symbolicatedFrame.file, let line = symbolicatedFrame.line
                {
                    output.writeString("  \(file):\(line)\n")
                }
            }
        }
        output.writeString("\n")
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
