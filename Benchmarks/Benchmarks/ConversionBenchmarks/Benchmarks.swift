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

import Benchmark
import Foundation
import Logging
import NIO
import ProfileRecorder
import ProfileRecorderSampleConversion
import SampleWorkload

let benchmarks = {
    Benchmark.defaultConfiguration = .init(
        warmupIterations: 1,
        maxDuration: .seconds(3)
    )

    let outputDir = "./output/conversion"
    let arrayAppendProfilePath = outputDir.appending("/array-append.swipr")

    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardError(label: label)
        handler.logLevel = .warning
        return handler
    }

    let logger = Logger(label: "benchmark")

    Benchmark.setup = {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: outputDir),
            withIntermediateDirectories: true
        )

        // create once a sample
        if !FileManager.default.fileExists(atPath: arrayAppendProfilePath) {
            Task {
                let array = ArrayAppend(blocking: true, threads: 20)
                array.run()
            }

            try await ProfileRecorderSampler.sharedInstance.requestSamples(
                outputFilePath: arrayAppendProfilePath,
                failIfFileExists: false,
                count: 1000,
                timeBetweenSamples: .milliseconds(1)
            )
        }
    }

    Benchmark("ArrayAppend FakeSymbolizer (PerfScript)") { benchmark in
        let converter = ProfileRecorderSampleConverter(
            config: SymbolizerConfiguration.default,
            threadPool: .singleton,
            group: .singletonMultiThreadedEventLoopGroup,
            renderer: PerfScriptOutputRenderer(),
            symbolizer: _ProfileRecorderFakeSymbolizer()
        )

        for _ in benchmark.scaledIterations {
            try await converter.convert(
                inputRawProfileRecorderFormatPath: arrayAppendProfilePath,
                outputPath: outputDir.appending("/array-append.fake.perf"),
                format: .pprofSymbolized,
                logger: logger
            )
        }
    }

    Benchmark("ArrayAppend convert to PerfScript") { benchmark in
        let symbolizer = ProfileRecorderSampler._makeDefaultSymbolizer()

        try await NIOThreadPool.singleton.runIfActive {
            try symbolizer.start()
        }

        let converter = ProfileRecorderSampleConverter(
            config: SymbolizerConfiguration.default,
            threadPool: .singleton,
            group: .singletonMultiThreadedEventLoopGroup,
            renderer: PerfScriptOutputRenderer(),
            symbolizer: symbolizer
        )

        for _ in benchmark.scaledIterations {
            try await converter.convert(
                inputRawProfileRecorderFormatPath: arrayAppendProfilePath,
                outputPath: outputDir.appending("/array-append.perf"),
                format: .pprofSymbolized,
                logger: logger
            )
        }
        try? await NIOThreadPool.singleton.runIfActive {
            try symbolizer.shutdown()
        }
    }

    Benchmark("ArrayAppend convert to pprof") { benchmark in
        let symbolizer = ProfileRecorderSampler._makeDefaultSymbolizer()

        try await NIOThreadPool.singleton.runIfActive {
            try symbolizer.start()
        }

        let converter = ProfileRecorderSampleConverter(
            config: SymbolizerConfiguration.default,
            threadPool: .singleton,
            group: .singletonMultiThreadedEventLoopGroup,
            renderer: PprofOutputRenderer(),
            symbolizer: symbolizer
        )

        for _ in benchmark.scaledIterations {
            try await converter.convert(
                inputRawProfileRecorderFormatPath: arrayAppendProfilePath,
                outputPath: outputDir.appending("/array-append.pprof"),
                format: .pprofSymbolized,
                logger: logger
            )
        }
        try? await NIOThreadPool.singleton.runIfActive {
            try symbolizer.shutdown()
        }
    }
}
