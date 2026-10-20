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
#elseif canImport(Musl)
@preconcurrency import Musl
#endif

import NIO
import _NIOFileSystem
import Dispatch
#if canImport(CProfileRecorderSampler) // only on macOS & Linux
@_implementationOnly import CProfileRecorderSampler
#endif

private let globalProfileRecorder: ProfileRecorderSampler = {
    #if canImport(CProfileRecorderSampler) // only on macOS & Linux
    swipr_initialize()
    #endif
    return ProfileRecorderSampler()
}()

/// Which threads the sampler records.
public enum ProfileRecorderSamplingMode: String, Codable & Sendable {
    /// All threads, running or waiting (on- and off-CPU).
    case wall
    /// Only threads running or runnable when sampled (on-CPU).
    case cpu
}

struct CouldNotOpenFileError: Error {
    var path: String
}

struct ProfileRecorderSamplerError: Error {
    var code: CInt
}

public final class ProfileRecorderSampler: Sendable {
    private let threadPool: NIOThreadPool

    internal struct UnsupportedOperation: Error {}

    /// A shared instance of a global in-process sampler.
    public static var sharedInstance: ProfileRecorderSampler {
        return globalProfileRecorder
    }

    /// A Boolean value that indicates whether this is a supported platform.
    public static var isSupportedPlatform: Bool {
        #if os(Linux)
        return true
        #elseif os(macOS)
        return true
        #else
        return false
        #endif
    }

    fileprivate init() {
        self.threadPool = NIOThreadPool(numberOfThreads: 1)
        self.threadPool.start()
    }

    private func requestSamples(
        output: CFilePointer,
        count: Int,
        timeBetweenSamples: TimeAmount,
        mode: ProfileRecorderSamplingMode,
        eventLoop: EventLoop
    ) -> EventLoopFuture<Void> {
        #if canImport(CProfileRecorderSampler) // only on macOS & Linux
        return self.threadPool.runIfActive(eventLoop: eventLoop) {
            let cMode: swipr_sampling_mode =
                switch mode {
                case .wall: SWIPR_SAMPLING_WALL
                case .cpu: SWIPR_SAMPLING_CPU
                }
            let ret = swipr_request_sample(
                output.handle,
                .init(count),
                .init(timeBetweenSamples.nanoseconds / 1000),
                cMode
            )
            fflush(output.handle)
            guard ret == 0 else {
                throw ProfileRecorderSamplerError(code: ret)
            }
        }
        #else
        return eventLoop.makeFailedFuture(UnsupportedOperation())
        #endif
    }

    /// Request and write the _raw_ samples to the output path you provide.
    ///
    /// - note: The samples will need to be symbolicated with `swipr-sample-conv`, alternatively use `ProfileRecorderServer` for automatically
    ///         getting the samples in a symbolicated standard format.
    ///
    /// - Parameters:
    ///   - outputFilePath: The output path for the raw samples.
    ///   - failIfFileExists: A Boolean value that indicates whether the function should fail if the output path file you provided already exists.
    ///   - count: The number of samples to capture.
    ///   - timeBetweenSamples: The time between samples.
    ///   - mode: Which threads to record.
    ///   - queue: The dispatch queue on which to run the sampler.
    ///   - handler: A closure the library calls when the samples are ready, providing the results.
    public func requestSamples(
        outputFilePath: String,
        failIfFileExists: Bool = true,
        count: Int,
        timeBetweenSamples: TimeAmount,
        mode: ProfileRecorderSamplingMode = .wall,
        queue: DispatchQueue,
        _ handler: @Sendable @escaping (Result<String, Error>) -> Void
    ) {
        self.requestSamples(
            outputFilePath: outputFilePath,
            failIfFileExists: failIfFileExists,
            count: count,
            timeBetweenSamples: timeBetweenSamples,
            mode: mode,
            eventLoop: MultiThreadedEventLoopGroup.singleton.any()
        ).whenComplete { result in
            queue.async {
                handler(result.map { outputFilePath })
            }
        }
    }

    /// Request and write the _raw_ samples to the output path you provide.
    ///
    /// - note: The samples will need to be symbolicated with `swipr-sample-conv`, alternatively use `ProfileRecorderServer` for automatically
    ///         getting the samples in a symbolicated standard format.
    ///
    /// - Parameters:
    ///   - outputFilePath: The output path for the raw samples.
    ///   - failIfFileExists: A Boolean value that indicates whether the function should fail if the output path file you provided already exists.
    ///   - count: The number of samples to capture.
    ///   - timeBetweenSamples: The time between samples.
    ///   - mode: Which threads to record.
    ///   - eventLoop: The event loop on which the sampler runs.
    public func requestSamples(
        outputFilePath: String,
        failIfFileExists: Bool = true,
        count: Int,
        timeBetweenSamples: TimeAmount,
        mode: ProfileRecorderSamplingMode = .wall,
        eventLoop: EventLoop
    ) -> EventLoopFuture<Void> {
        if outputFilePath == "-" {
            return self.requestSamples(
                output: CFilePointer(stderr),
                count: count,
                timeBetweenSamples: timeBetweenSamples,
                mode: mode,
                eventLoop: eventLoop
            )
        } else {
            guard let outputRaw = fopen(outputFilePath, "w\(failIfFileExists ? "x" : "")") else {
                return eventLoop.makeFailedFuture(CouldNotOpenFileError(path: outputFilePath))
            }
            // stdio sizes the buffer from st_blksize, 4 KiB on APFS: a write(2) every ~60 stack frames.
            // Own buffer: glibc ignores the size when `buf` is nil.
            let bufferSize = 1 * 1024 * 1024 // 1 MiB
            nonisolated(unsafe) let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
            setvbuf(outputRaw, buffer, _IOFBF, bufferSize)
            let output = CFilePointer(outputRaw)

            return self.requestSamples(
                output: output,
                count: count,
                timeBetweenSamples: timeBetweenSamples,
                mode: mode,
                eventLoop: eventLoop
            ).always { _ in
                fclose(output.handle)
                buffer.deallocate()
            }
        }
    }

    /// Request and write the _raw_ samples to the output path you provide.
    ///
    /// - note: The samples will need to be symbolicated with `swipr-sample-conv`, alternatively use `ProfileRecorderServer` for automatically
    ///         getting the samples in a symbolicated standard format.
    ///
    /// - Parameters:
    ///   - outputFilePath: The output path for the raw samples.
    ///   - failIfFileExists: A Boolean value that indicates whether the function should fail if the output path file you provided already exists.
    ///   - count: The number of samples to capture.
    ///   - timeBetweenSamples: The time between samples.
    ///   - mode: Which threads to record.
    public func requestSamples(
        outputFilePath: String,
        failIfFileExists: Bool = true,
        count: Int,
        timeBetweenSamples: TimeAmount,
        mode: ProfileRecorderSamplingMode = .wall
    ) async throws {
        return try await self.requestSamples(
            outputFilePath: outputFilePath,
            failIfFileExists: failIfFileExists,
            count: count,
            timeBetweenSamples: timeBetweenSamples,
            mode: mode,
            eventLoop: .singletonMultiThreadedEventLoopGroup.any()
        ).get()
    }
}

struct CFilePointer: @unchecked Sendable {
    let handle: UnsafeMutablePointer<FILE>

    init(_ handle: UnsafeMutablePointer<FILE>) {
        self.handle = handle
    }
}
