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
import Logging
import Foundation
import ProfileRecorder

public struct ProfileRecorderSampleConverter: Sendable {
    let symbolizerConfiguration: SymbolizerConfiguration
    var renderer: any ProfileRecorderSampleConversionOutputRenderer
    let threadPool: NIOThreadPool
    let group: EventLoopGroup
    let symbolizer: SymbolizerMaker

    public struct Error: Swift.Error {
        var message: String
    }

    // TODO: Remove once we can remove the deprecated init
    enum SymbolizerMaker: Sendable {
        case symbolizer(any Symbolizer)
        case maker(@Sendable () throws -> any (Symbolizer & Sendable))
    }

    internal init(
        config: SymbolizerConfiguration,
        threadPool: NIOThreadPool,
        group: any EventLoopGroup,
        renderer: any ProfileRecorderSampleConversionOutputRenderer,
        symbolizer: SymbolizerMaker
    ) {
        self.symbolizerConfiguration = config
        self.renderer = renderer
        self.symbolizer = symbolizer
        self.threadPool = threadPool
        self.group = group
    }

    @available(*, deprecated, message: "Please provide an initialised symboliser")
    public init(
        config: SymbolizerConfiguration,
        threadPool: NIOThreadPool = .singleton,
        group: any EventLoopGroup = .singletonMultiThreadedEventLoopGroup,
        renderer: any ProfileRecorderSampleConversionOutputRenderer,
        makeSymbolizer: @Sendable @escaping () throws -> any Symbolizer
    ) {
        self.init(
            config: config,
            threadPool: threadPool,
            group: group,
            renderer: renderer,
            symbolizer: .maker(makeSymbolizer)
        )
    }

    public init(
        config: SymbolizerConfiguration,
        threadPool: NIOThreadPool = .singleton,
        group: any EventLoopGroup = .singletonMultiThreadedEventLoopGroup,
        renderer: any ProfileRecorderSampleConversionOutputRenderer,
        symbolizer: any Symbolizer
    ) {
        self.init(
            config: config,
            threadPool: threadPool,
            group: group,
            renderer: renderer,
            symbolizer: .symbolizer(symbolizer)
        )
    }

    public func convert(
        inputRawProfileRecorderFormatPath fromPath: String,
        outputPath toPath: String,
        format: ProfileRecorderOutputFormat,
        logger: Logger
    ) async throws {
        return try await self.threadPool.runIfActive {
            var `self` = self
            try self.convertSync(
                inputRawProfileRecorderFormatPath: fromPath,
                outputPath: toPath,
                format: format,
                logger: logger
            )
        }
    }

    @available(*, noasync, message: "blocks calling thread")
    public mutating func convertSync(
        inputRawProfileRecorderFormatPath fromPath: String,
        outputPath toPath: String,
        format: ProfileRecorderOutputFormat,
        logger: Logger
    ) throws {
        switch self.symbolizer {
        case .symbolizer(let symbolizer):
            return try self.convertSync(
                inputRawProfileRecorderFormatPath: fromPath,
                outputPath: toPath,
                underlyingSymbolizer: symbolizer,
                format: format,
                logger: logger
            )
        case .maker(let maker):
            let symbolizer = try maker()
            try symbolizer.start()
            defer {
                try! symbolizer.shutdown()
            }
            return try self.convertSync(
                inputRawProfileRecorderFormatPath: fromPath,
                outputPath: toPath,
                underlyingSymbolizer: symbolizer,
                format: format,
                logger: logger
            )
        }
    }

    @available(*, noasync, message: "blocks calling thread")
    internal mutating func convertSync(
        inputRawProfileRecorderFormatPath fromPath: String,
        outputPath toPath: String,
        underlyingSymbolizer: any Symbolizer,
        format: ProfileRecorderOutputFormat,
        logger: Logger
    ) throws {
        var accumulatedErrors: [any Swift.Error] = []
        do {
            let input = fromPath == "-" ? stdin : fopen(fromPath, "r")
            guard let input = input else {
                throw Error(message: "Could not open \(fromPath), errno: \(errno)")
            }
            defer {
                if fromPath != "-" {
                    fclose(input)
                }
            }
            let output = toPath == "-" ? stdout : fopen(toPath, "w")
            guard let output = output else {
                throw Error(message: "Could not open \(toPath), errno: \(errno)")
            }
            defer {
                if toPath != "-" {
                    fclose(output)
                }
            }
            let decoder = JSONDecoder()

            var config = ProfileRecorderSampleConversionConfiguration.default
            config.includeFileLineInformation = self.symbolizerConfiguration.perfScriptOutputWithFileLineInformation

            var sampleConfig = SampleConfig(
                currentTimeSeconds: 0,
                currentTimeNanoseconds: 0,
                microSecondsBetweenSamples: 1,
                sampleCount: 0
            )
            var vmaps: [DynamicLibMapping] = []
            var vmapsRead = true
            var currentSample: Sample? = nil
            var bufferCapacity: ssize_t = 1024
            var buffer: UnsafeMutablePointer<CChar>? = UnsafeMutablePointer<CChar>.allocate(
                capacity: Int(bufferCapacity)
            )
            defer {
                buffer!.deallocate()
            }

            var symboliser: CachedSymbolizer? = nil
            defer {
                if let symboliser = symboliser {
                    do {
                        let renderedSample = try self.renderer.finalise(
                            sampleConfiguration: sampleConfig,
                            configuration: config,
                            symbolizer: symboliser
                        )
                        renderedSample.withUnsafeReadableBytes { renderedPtr in
                            _ = fwrite(renderedPtr.baseAddress, 1, renderedPtr.count, output)
                        }
                        logger.info("done symbolising", metadata: ["cached-sym": "\(symboliser.description)"])
                    } catch {
                        accumulatedErrors.append(error)
                    }
                }
            }

            let messageHeaderPrefix = "[SWIPR] "
            let messageHeaderPrefixLength = messageHeaderPrefix.count
            let messageHeaderTypeLength = 4
            let messageHeaderLength = messageHeaderPrefixLength + messageHeaderTypeLength + 1

            while getline(&buffer, &bufferCapacity, input) != -1 {
                let line = String(cString: buffer!)
                guard line.hasPrefix(messageHeaderPrefix) else {
                    continue
                }
                switch line
                    .dropFirst(messageHeaderPrefixLength)
                    .prefix(messageHeaderTypeLength)
                {
                case "MESG":
                    guard
                        let message = try? decoder.decode(
                            Message.self,
                            from: Data(line.dropFirst(messageHeaderLength).utf8)
                        )
                    else {
                        continue
                    }
                    logger.info("\(message.message)")
                    if let _ = message.exit {
                        throw Error(message: message.message)
                    }
                case "CONF":
                    guard
                        let conf = try? decoder.decode(
                            SampleConfig.self,
                            from: Data(line.dropFirst(messageHeaderLength).utf8)
                        )
                    else {
                        continue
                    }
                    sampleConfig = conf
                case "VERS":
                    guard
                        let version = try? decoder.decode(
                            Version.self,
                            from: Data(line.dropFirst(messageHeaderLength).utf8)
                        )
                    else {
                        logger.error("Could not decode Swift Profile Recorder version", metadata: ["line": "\(line)"])
                        throw Error(message: "Could not decode Swift Profile Recorder version in '\(line)'")
                    }
                    guard version.version == 1 else {
                        logger.error(
                            "This is a Swift Profile Recorder trace of the wrong version, but we're only compatible with version 1",
                            metadata: ["trace-version": "\(version.version)", "our-version": "1"]
                        )
                        throw Error(
                            message:
                                "Can only decode Swift Profile Recorder version 1 traces, this is \(version.version)"
                        )
                    }
                case "VMAP":
                    guard
                        let mapping = try? decoder.decode(
                            DynamicLibMapping.self,
                            from: Data(line.dropFirst(messageHeaderLength).utf8)
                        )
                    else {
                        continue
                    }

                    if vmapsRead {
                        symboliser = nil
                        vmaps.removeAll()
                        vmapsRead = false
                    }
                    vmaps.append(mapping)
                case "SMPL":
                    vmapsRead = true
                    if symboliser == nil {
                        symboliser = CachedSymbolizer(
                            configuration: .default,
                            symbolizer: underlyingSymbolizer,
                            dynamicLibraryMappings: vmaps,
                            group: group,
                            logger: logger
                        )
                    }
                    guard
                        let header = try? decoder.decode(
                            SampleHeader.self,
                            from: Data(line.dropFirst(messageHeaderLength).utf8)
                        )
                    else {
                        logger.warning(
                            "failed to parse line, ignoring",
                            metadata: ["line": "\(line.dropFirst(messageHeaderLength)))"]
                        )
                        continue
                    }

                    currentSample = Sample(sampleHeader: header, stack: [])
                case "STCK":
                    let json = line.dropFirst(messageHeaderLength).utf8

                    // attempt the fast parser
                    if let stackFrame = json.attemptFastParseStackFrame() {
                        currentSample?.stack.append(stackFrame)
                        continue
                    }
                    guard
                        let stackFrame = try? decoder.decode(
                            StackFrame.self,
                            from: Data(json)
                        )
                    else {
                        continue
                    }
                    currentSample?.stack.append(stackFrame)
                case "DONE":
                    if let sample = currentSample, let symbolizer = symboliser {
                        do {
                            var sample = sample
                            sample.stack = sample.stack.dropFirst().map { frame in
                                // We would have received the instruction pointer just _behind_ the actual instruction,
                                // so to accurately get the right frame, we need to get the intruction prior. On ARM
                                // that's easy (subtract 4) but on Intel that's impossible so we just subtract 1
                                // instead.
                                var fixedUpStackFrame = frame
                                if fixedUpStackFrame.instructionPointer >= 4 {
                                    #if arch(arm) || arch(arm64)
                                    // Known fixed-width instruction format
                                    fixedUpStackFrame.instructionPointer -= 4
                                    #else
                                    // Unknown, subtract 1
                                    fixedUpStackFrame.instructionPointer -= 1
                                    #endif
                                }

                                return fixedUpStackFrame
                            }
                            let renderedSample = try self.renderer.consumeSingleSample(
                                sample,
                                configuration: config,
                                symbolizer: symbolizer
                            )
                            renderedSample.withUnsafeReadableBytes { renderedPtr in
                                _ = fwrite(renderedPtr.baseAddress, 1, renderedPtr.count, output)
                            }
                        } catch {
                            accumulatedErrors.append(error)
                        }
                    }
                default:
                    logger.warning(
                        "unknown line, ignoring",
                        metadata: [
                            "line": "\(line.dropFirst(messageHeaderPrefixLength).prefix(messageHeaderTypeLength)))"
                        ]
                    )
                    continue
                }
            }
        }
        if let firstError = accumulatedErrors.first {
            throw firstError
        }
    }
}
