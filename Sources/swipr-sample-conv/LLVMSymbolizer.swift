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

#if canImport(Glibc)
@preconcurrency import Glibc // Sendability of stdout/stderr/..., needs to be at the top of the file
#endif
import _ProfileRecorderSampleConversion
import NIO
import Foundation
import Logging
import NIOConcurrencyHelpers
import NIOExtras

public struct LLVMSymboliserConfig: Sendable {
    var viaJSON: Bool
    var unstuckerWorkaround: Bool
}

#if canImport(Darwin) && !os(macOS)
// LLVMSymboliser is unsupported on i/watch/visionOS
internal final class LLVMSymboliser: Symbolizer & Sendable {
    struct UnsupportedOSError: Error {}

    internal init(
        config: LLVMSymboliserConfig,
        group: EventLoopGroup,
        logger: Logger
    ) {}

    func start() throws {
        throw UnsupportedOSError()
    }

    internal func symbolise(
        fileVirtualAddressIP: UInt,
        library: DynamicLibMapping,
        logger: Logger
    ) throws -> SymbolisedStackFrame {
        throw UnsupportedOSError()
    }

    func shutdown() throws {
        throw UnsupportedOSError()
    }

    var description: String {
        return "not supported on this OS"
    }
}
#else
/// Symbolises `StackFrame`s using `llvm-symbolizer`.
internal final class LLVMSymboliser: Symbolizer & Sendable {
    private let group: EventLoopGroup
    private let logger: Logger
    private let config: LLVMSymboliserConfig
    private let state = NIOLockedValueBox(State())

    struct State: Sendable {
        var process: Process? = nil
        var channel: Channel? = nil
        var unstucker: RepeatedTask? = nil
    }

    internal init(
        config: LLVMSymboliserConfig,
        group: EventLoopGroup,
        logger: Logger
    ) {
        self.config = config
        self.group = group
        self.logger = logger
    }

    @available(*, noasync, message: "Blocks the calling thread")
    internal func start() throws {
        let stdIn = Pipe()
        let stdOut = Pipe()

        let process = Process()
        process.standardInput = stdIn.fileHandleForReading
        process.standardOutput = stdOut.fileHandleForWriting
        let symboliserPath: String
        if let path = ProcessInfo.processInfo.environment["SWIPR_LLVM_SYMBOLIZER"] {
            symboliserPath = path
        } else {
            symboliserPath = "/usr/bin/llvm-symbolizer"
        }

        process.executableURL = URL(fileURLWithPath: symboliserPath)
        process.arguments =
            [
                "--print-address",
                "--demangle",
                "--inlining=true",
                "--functions=linkage",
                "--basenames",
            ] + (self.config.viaJSON ? ["--output-style=JSON"] : [])
        try process.run()

        let channel: Channel = try NIOPipeBootstrap(group: self.group)
            .channelInitializer {
                [
                    logger = self.logger,
                    viaJSON = self.config.viaJSON
                ] channel in
                do {
                    try channel.pipeline.syncOperations.addHandlers([
                        ByteToMessageHandler(LineBasedFrameDecoder()),
                        viaJSON ? LLVMJSONOutputParserHandler() : LLVMOutputParserHandler(),
                        LLVMSymbolizerEncoderHandler(logger: logger),
                        LogErrorHandler(logger: logger),
                        RequestResponseHandler<LLVMSymbolizerQuery, SymbolisedStackFrame>(),
                    ])
                    return channel.eventLoop.makeSucceededVoidFuture()
                } catch {
                    return channel.eventLoop.makeFailedFuture(error)
                }
            }
            .takingOwnershipOfDescriptors(
                input: dup(stdOut.fileHandleForReading.fileDescriptor),
                output: dup(stdIn.fileHandleForWriting.fileDescriptor)
            ).wait()
        var unstucker: RepeatedTask? = nil
        if self.config.unstuckerWorkaround {
            unstucker = channel.eventLoop.scheduleRepeatedTask(
                initialDelay: .milliseconds(1000),
                delay: .milliseconds(1000)
            ) { _ in
                let p = channel.eventLoop.makePromise(of: SymbolisedStackFrame.self)
                channel.writeAndFlush((StackFrame(instructionPointer: .max, stackPointer: 0), p)).cascadeFailure(to: p)
                p.futureResult.whenSuccess { str in
                    if !(str.allFrames.first?.address ?? 0 == .max) {
                        fputs("unexpected PING message result '\(str)'\n", stderr)
                    }
                }
            }
        }

        self.state.withLockedValue { state in
            assert(state.channel == nil)
            assert(state.process == nil)
            assert(state.unstucker == nil)

            state.channel = channel
            state.process = process
            state.unstucker = unstucker
        }
    }

    @available(*, noasync, message: "Blocks the calling thread")
    internal func symbolise(
        fileVirtualAddressIP: UInt,
        library: DynamicLibMapping,
        logger: Logger
    ) throws -> SymbolisedStackFrame {
        struct TimeoutError: Error {
            var fileVirtualAddressIP: UInt
            var library: DynamicLibMapping
        }
        let channel = self.state.withLockedValue { $0.channel }!
        let promise = channel.eventLoop.makePromise(of: SymbolisedStackFrame.self)
        let sched = promise.futureResult.eventLoop.scheduleTask(in: .seconds(10)) {
            promise.fail(TimeoutError(fileVirtualAddressIP: fileVirtualAddressIP, library: library))
        }
        do {
            let query = LLVMSymbolizerQuery(address: fileVirtualAddressIP, library: library)
            try channel.writeAndFlush((query, promise)).wait()
        } catch {
            self.logger.error("write to llvm-symbolizer pipe failed", metadata: ["error": "\(error)"])
            promise.fail(error)
        }
        promise.futureResult.whenComplete { _ in
            sched.cancel()
        }
        return try promise.futureResult.wait()
    }

    @available(*, noasync, message: "Blocks the calling thread")
    internal func shutdown() throws {
        self.logger.debug("shutting down")
        let state = self.state.withLockedValue { state in
            let oldState = state
            state = State()
            return oldState
        }
        state.unstucker?.cancel(promise: nil)

        state.process?.terminate()

        do {
            try state.channel?.close().wait()
        } catch ChannelError.alreadyClosed {
            // ok
        }
    }

    deinit {
        assert(
            self.state.withLockedValue { state in
                assert(state.channel == nil)
                assert(state.process == nil)
                assert(state.unstucker == nil)
                return state.channel == nil && state.process == nil && state.unstucker == nil
            }
        )
    }

    public var description: String {
        return "LLVMSymbolizer"
    }
}
#endif

final class LogErrorHandler: ChannelInboundHandler {
    typealias InboundIn = NIOAny

    let logger: Logger

    internal init(logger: Logger) {
        self.logger = logger
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        defer {
            context.fireErrorCaught(error)
        }
        self.logger.warning("error whilst interacting with llvm-symbolizer", metadata: ["error": "\(error)"])
    }
}
