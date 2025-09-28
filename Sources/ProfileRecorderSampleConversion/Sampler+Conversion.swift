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

import ProfileRecorder
import Logging
import NIO
import _NIOFileSystem

public enum ProfileRecorderOutputFormat: String, Codable & Sendable {
    case perfSymbolized
    case pprofSymbolized
    case flamegraphCollapsedSymbolized
    case raw
}

extension ProfileRecorderSampler {
    public func _withSamples<R: Sendable>(
        sampleCount: Int,
        timeBetweenSamples: TimeAmount,
        format: ProfileRecorderOutputFormat,
        symbolizer: any Symbolizer,
        logger: Logger,
        _ body: (String) async throws -> R
    ) async throws -> R {
        try await FileSystem.shared.withTemporaryDirectory {
            tmpDirHandle,
            tmpDirPath in
            let rawSamplesPath = tmpDirPath.appending("samples.raw")
            let symbolisedSamplesPath: FilePath

            var logger = logger
            logger[metadataKey: "sample-count"] = "\(sampleCount)"
            logger[metadataKey: "time-between-samples"] = "\(timeBetweenSamples.prettyPrint)"
            logger[metadataKey: "raw-samples-path"] = "\(rawSamplesPath)"
            logger[metadataKey: "symbolizer"] = "\(symbolizer)"
            switch format {
            case .perfSymbolized:
                symbolisedSamplesPath = tmpDirPath.appending("samples.perf")
                logger[metadataKey: "symbolicated-samples-path"] = "\(symbolisedSamplesPath.string)"
            case .pprofSymbolized:
                symbolisedSamplesPath = tmpDirPath.appending("samples.pprof.pb")
                logger[metadataKey: "symbolicated-samples-path"] = "\(symbolisedSamplesPath.string)"
            case .flamegraphCollapsedSymbolized:
                symbolisedSamplesPath = tmpDirPath.appending("samples.flamegraph.collapsed")
                logger[metadataKey: "symbolicated-samples-path"] = "\(symbolisedSamplesPath.string)"
            case .raw:
                symbolisedSamplesPath = tmpDirPath.appending("samples.raw")
            }

            logger.info("requesting raw samples")
            try await self.requestSamples(
                outputFilePath: rawSamplesPath.string,
                failIfFileExists: true,
                count: sampleCount,
                timeBetweenSamples: timeBetweenSamples
            )
            logger.info("raw samples complete")
            switch format {
            case .perfSymbolized, .pprofSymbolized, .flamegraphCollapsedSymbolized:
                let renderer: any ProfileRecorderSampleConversionOutputRenderer
                switch format {
                    case .perfSymbolized:
                    renderer = PerfScriptOutputRenderer()
                case .pprofSymbolized:
                    renderer = PprofOutputRenderer()
                case .flamegraphCollapsedSymbolized:
                    renderer = FlamegraphCollapsedOutputRenderer()
                case .raw:
                    fatalError("we shouldn't be here")
                }
                let converter = ProfileRecorderSampleConverter(config: .default, renderer: renderer, symbolizer: symbolizer)
                try await converter.convert(
                    inputRawProfileRecorderFormatPath: rawSamplesPath.string,
                    outputPath: symbolisedSamplesPath.string,
                    format: .perfSymbolized,
                    logger: logger
                )
                logger.info("samples symbolicated")
                return try await body(symbolisedSamplesPath.string)
            case .raw:
                return try await body(rawSamplesPath.string)
            }
        }
    }

    public static func _makeDefaultSymbolizer() -> some Symbolizer {
        #if canImport(Darwin)
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
        let symbolizer = CoreSymbolicationSymboliser()
        #else
        #warning("unsupported Darwin platform, falling back to dummy symbolizer")
        let symbolizer = _ProfileRecorderFakeSymbolizer()
        #endif
        #else
        let symbolizer = NativeELFSymboliser()
        #endif
        return symbolizer
    }

    public func withSymbolizedSamplesInPerfScriptFormat<R: Sendable>(
        sampleCount: Int,
        timeBetweenSamples: TimeAmount,
        logger: Logger,
        _ body: (String) async throws -> R
    ) async throws -> R {
        let symbolizer = ProfileRecorderSampler._makeDefaultSymbolizer()
        try symbolizer.start()
        defer {
            try! symbolizer.shutdown()
        }
        return try await self._withSamples(
            sampleCount: sampleCount,
            timeBetweenSamples: timeBetweenSamples,
            format: .perfSymbolized,
            symbolizer: symbolizer,
            logger: logger,
            body
        )
    }
}
