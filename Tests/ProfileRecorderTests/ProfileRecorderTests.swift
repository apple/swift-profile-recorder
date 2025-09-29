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

import Atomics
import XCTest
import NIO
import NIOConcurrencyHelpers
import Logging
import _NIOFileSystem
@testable import ProfileRecorder
import ProfileRecorderSampleConversion

#if !canImport(Darwin)
// We're using a terrible workaround to work around the lack of frame pointers
// in libdispatch on non-Darwin.
// (https://github.com/swiftlang/swift-corelibs-libdispatch/issues/909)
typealias DispatchSemaphore = WorkaroundSemaphore
#endif

final class ProfileRecorderTests: XCTestCase {
    var tempDirectory: String! = nil
    var group: EventLoopGroup! = nil
    var logger: Logger! = nil

    func testBasicJustRequestOneSample() throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        XCTAssertNoThrow(
            try ProfileRecorderSampler.sharedInstance.requestSamples(
                outputFilePath: "\(self.tempDirectory!)/samples.samples",
                count: 1,
                timeBetweenSamples: .nanoseconds(0),
                eventLoop: self.group.next()
            ).wait()
        )
    }

    func testMultipleSamples() throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        XCTAssertNoThrow(
            try ProfileRecorderSampler.sharedInstance.requestSamples(
                outputFilePath: "\(self.tempDirectory!)/samples.samples",
                count: 10,
                timeBetweenSamples: .nanoseconds(0),
                eventLoop: self.group.next()
            ).wait()
        )
    }

    func testSamplingWithALargeNumberOfThreads() throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        let threads = NIOThreadPool(numberOfThreads: 128)
        threads.start()
        defer {
            XCTAssertNoThrow(try threads.syncShutdownGracefully())
        }

        XCTAssertNoThrow(
            try ProfileRecorderSampler.sharedInstance.requestSamples(
                outputFilePath: "\(self.tempDirectory!)/samples.samples",
                count: 100,
                timeBetweenSamples: .nanoseconds(0),
                eventLoop: self.group.next()
            ).wait()
        )
    }

    func testSamplingWhilstThreadsAreCreatedAndDying() throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        let samples = ProfileRecorderSampler.sharedInstance.requestSamples(
            outputFilePath: "\(self.tempDirectory!)/samples.samples",
            count: 1000,
            timeBetweenSamples: .microseconds(100),
            eventLoop: self.group.next()
        )
        let keepRunning = ManagedAtomic<Bool>(true)
        samples.whenComplete { _ in
            keepRunning.store(false, ordering: .relaxed)
        }
        while keepRunning.load(ordering: .relaxed) {
            XCTAssertNoThrow(try MultiThreadedEventLoopGroup(numberOfThreads: 64).syncShutdownGracefully())
        }

        XCTAssertNoThrow(try samples.wait())
    }

    // Experiencing issues due to the lack of frame pointers
    // (https://github.com/swiftlang/swift-corelibs-libdispatch/issues/909)
    func testSymbolicatedSamplesWork() async throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        let reachedQuuuxSem = DispatchSemaphore(value: 0)
        let unblockSem = DispatchSemaphore(value: 0)
        self.logger.info("spawning thread to be blocked")
        async let done: () = NIOThreadPool.singleton.runIfActive {
            RECGONISABLE_FUNCTION_FOO(reachedQuuuxSem: reachedQuuuxSem, unblockSem: unblockSem)
        }
        do {
            defer {
                unblockSem.signal() // unblock that thread
            }
            self.logger.info("waiting for conds")
            await withCheckedContinuation { cont in
                DispatchQueue.global().async {
                    reachedQuuuxSem.wait()
                    cont.resume()
                }
            }
            self.logger.info("done")

            // okay, we should have a thread blocked in RECGONISABLE_FUNCTION_QUUUX() now

            let sampleBytes = try await ProfileRecorderSampler.sharedInstance.withSymbolizedSamplesInPerfScriptFormat(
                sampleCount: 1,
                timeBetweenSamples: .nanoseconds(0),
                logger: self.logger
            ) { file in
                try await ByteBuffer(contentsOf: FilePath(file), maximumSizeAllowed: .mebibytes(32))
            }
            let samples = String(buffer: sampleBytes).split(separator: "\n")
            var found = false
            for index in samples.indices {
                let currentLine = samples[index]
                guard currentLine.contains("RECGONISABLE_FUNCTION_QUUX") else {
                    continue
                }
                found = true
                let interestingLines = Array(samples.dropFirst(index - 1).prefix(6))
                guard interestingLines.count == 6 else {
                    XCTFail("Expected 6 lines, got \(interestingLines.count) in \(interestingLines)")
                    return
                }

                XCTAssert(interestingLines[0].contains("RECGONISABLE_FUNCTION_QUUUX"), "\(interestingLines[0])")
                XCTAssert(interestingLines[1].contains("RECGONISABLE_FUNCTION_QUUX"), "\(interestingLines[1])")
                XCTAssert(interestingLines[2].contains("RECGONISABLE_FUNCTION_QUX"), "\(interestingLines[2])")
                XCTAssert(interestingLines[3].contains("RECGONISABLE_FUNCTION_BUZ"), "\(interestingLines[3])")
                XCTAssert(interestingLines[4].contains("RECGONISABLE_FUNCTION_BAR"), "\(interestingLines[4])")
                XCTAssert(interestingLines[5].contains("RECGONISABLE_FUNCTION_FOO"), "\(interestingLines[5])")
            }
            XCTAssert(found, "\(samples.joined(separator: "\n"))")
        }
        try await done
    }

    func testSymbolsAreMangled() async throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        let reachedQuuuxSem = DispatchSemaphore(value: 0)
        let unblockSem = DispatchSemaphore(value: 0)
        async let done: Void = NIOThreadPool.singleton.runIfActive {
            RECGONISABLE_FUNCTION_FOO(reachedQuuuxSem: reachedQuuuxSem, unblockSem: unblockSem)
        }
        do {
            defer {
                unblockSem.signal()
            }
            self.logger.info("waiting for thread to be ready and stall in semaphore")
            await withCheckedContinuation { cont in
                DispatchQueue.global().async {
                    reachedQuuuxSem.wait()
                    cont.resume()
                }
            }
            self.logger.info("thread is ready")

            let sampleBytes = try await ProfileRecorderSampler.sharedInstance.withSymbolizedSamplesInPerfScriptFormat(
                sampleCount: 1,
                timeBetweenSamples: .nanoseconds(0),
                logger: self.logger
            ) { file in
                try await ByteBuffer(contentsOf: FilePath(file), maximumSizeAllowed: .mebibytes(16))
            }
            let samples = String(buffer: sampleBytes)
            // We can only match the @inline(never) function FOO with mangling (the others might be inlined)
            XCTAssert(samples.contains("s20ProfileRecorderTests25RECGONISABLE_FUNCTION_FOO"), "foo missing: \(samples)")
            XCTAssert(samples.contains("RECGONISABLE_FUNCTION_QUUUX"), "quuux missing: \(samples)")
        }
        try await done
    }

    // MARK: - Setup/teardown
    override func setUp() {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        self.tempDirectory = NSTemporaryDirectory() + "/ProfileRecorderTests-\(UUID())"
        XCTAssertNoThrow(
            try FileManager.default.createDirectory(
                atPath: self.tempDirectory,
                withIntermediateDirectories: false
            )
        )
        self.logger = Logger(label: "ProfileRecorderTests")
    }

    override func tearDown() {
        self.logger = nil
        XCTAssertNoThrow(try self.group.syncShutdownGracefully())
        self.group = nil

        XCTAssertNoThrow(try FileManager.default.removeItem(atPath: self.tempDirectory))
        self.tempDirectory = nil
    }
}

@inline(never)
func RECGONISABLE_FUNCTION_FOO(reachedQuuuxSem: DispatchSemaphore, unblockSem: DispatchSemaphore) {
    RECGONISABLE_FUNCTION_BAR(reachedQuuuxSem: reachedQuuuxSem, unblockSem: unblockSem)
}

func RECGONISABLE_FUNCTION_BAR(reachedQuuuxSem: DispatchSemaphore, unblockSem: DispatchSemaphore) {
    RECGONISABLE_FUNCTION_BUZ(reachedQuuuxSem: reachedQuuuxSem, unblockSem: unblockSem)
}

func RECGONISABLE_FUNCTION_BUZ(reachedQuuuxSem: DispatchSemaphore, unblockSem: DispatchSemaphore) {
    RECGONISABLE_FUNCTION_QUX(reachedQuuuxSem: reachedQuuuxSem, unblockSem: unblockSem)
}

func RECGONISABLE_FUNCTION_QUX(reachedQuuuxSem: DispatchSemaphore, unblockSem: DispatchSemaphore) {
    RECGONISABLE_FUNCTION_QUUX(reachedQuuuxSem: reachedQuuuxSem, unblockSem: unblockSem)
}

func RECGONISABLE_FUNCTION_QUUX(reachedQuuuxSem: DispatchSemaphore, unblockSem: DispatchSemaphore) {
    RECGONISABLE_FUNCTION_QUUUX(reachedQuuuxSem: reachedQuuuxSem, unblockSem: unblockSem)
}

func RECGONISABLE_FUNCTION_QUUUX(reachedQuuuxSem: DispatchSemaphore, unblockSem: DispatchSemaphore) {
    reachedQuuuxSem.signal()
    unblockSem.wait()
}

// We're using a terrible workaround to work around the lack of frame pointers
// in libdispatch on non-Darwin.
// (https://github.com/swiftlang/swift-corelibs-libdispatch/issues/909)
final class WorkaroundSemaphore: Sendable {
    let backing: ConditionLock<Int>

    init(value: Int) {
        precondition(value == 0, "this is not a proper semaphore, just a workaround")
        self.backing = ConditionLock(value: 0)
    }

    @inline(never)
    func signal() {
        precondition(self.backing.value == 0, "signalled at least twice")
        self.backing.lock(whenValue: 0)
        self.backing.unlock(withValue: 1)
    }

    @inline(never)
    func wait(crash: Bool = false) {
        if crash {
            fatalError()
        }
        self.backing.lock(whenValue: 1)
        self.backing.unlock(withValue: 0)
    }
}
