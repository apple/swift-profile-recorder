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
import _ProfileRecorderSampleConversion

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

    func testSamplingMoreThreadsThanTheLimit() async throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        let threads = NIOThreadPool(numberOfThreads: 1100)
        threads.start()
        defer {
            XCTAssertNoThrow(try threads.syncShutdownGracefully())
        }

        let ticks = 5
        let path = "\(self.tempDirectory!)/samples.samples"
        try await ProfileRecorderSampler.sharedInstance.requestSamples(
            outputFilePath: path,
            count: ticks,
            timeBetweenSamples: .nanoseconds(0)
        )
        let data = try await ByteBuffer(contentsOf: FilePath(path), maximumSizeAllowed: .mebibytes(64))
        let samples = String(buffer: data).split(separator: "\n").filter { $0.hasPrefix("[SWIPR] SMPL") }.count
        // SWIPR_MAX_MUTATOR_THREADS
        XCTAssertLessThanOrEqual(samples, ticks * 1024)
        XCTAssertGreaterThan(samples, ticks * 1000)
    }

    func testEveryThreadIsSampledEveryTick() async throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        // Starts the sampler's own threads first so the idle threads come last in the OS thread list.
        try await ProfileRecorderSampler.sharedInstance.requestSamples(
            outputFilePath: "\(self.tempDirectory!)/warmup.samples",
            count: 1,
            timeBetweenSamples: .nanoseconds(0)
        )

        let threadCount = 4
        // Each thread bumps the count once named; -1 releases them.
        let state = ConditionLock(value: 0)
        for i in 0..<threadCount {
            Thread {
                Thread.current.name = "swipr-idle-\(i)"
                state.lock(whenValue: i)
                state.unlock(withValue: i + 1)
                state.lock(whenValue: -1)
                state.unlock()
            }.start()
        }
        state.lock(whenValue: threadCount)
        state.unlock()
        defer {
            state.lock()
            state.unlock(withValue: -1)
        }

        let ticks = 20
        let path = "\(self.tempDirectory!)/samples.samples"
        try await ProfileRecorderSampler.sharedInstance.requestSamples(
            outputFilePath: path,
            count: ticks,
            timeBetweenSamples: .nanoseconds(0)
        )
        let data = try await ByteBuffer(contentsOf: FilePath(path), maximumSizeAllowed: .mebibytes(64))
        let samples = String(buffer: data).split(separator: "\n").filter {
            $0.hasPrefix("[SWIPR] SMPL") && $0.contains("\"name\": \"swipr-idle-")
        }.count
        XCTAssertEqual(samples, ticks * threadCount)
    }

    func testSamplingWithThreadThatBlocksSIGPROF() async throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        let threadReady = DispatchSemaphore(value: 0)
        let threadUnblock = DispatchSemaphore(value: 0)
        let threadDone = DispatchSemaphore(value: 0)

        let blockingThread = Thread {
            var set = sigset_t()
            sigemptyset(&set)
            sigaddset(&set, SIGPROF)
            pthread_sigmask(SIG_BLOCK, &set, nil)

            threadReady.signal()
            threadUnblock.wait()
            threadDone.signal()
        }
        blockingThread.start()

        threadReady.wait()

        let startTime = DispatchTime.now()
        XCTAssertNoThrow(
            try ProfileRecorderSampler.sharedInstance.requestSamples(
                outputFilePath: "\(self.tempDirectory!)/samples.samples",
                count: 10,
                timeBetweenSamples: .nanoseconds(0),
                eventLoop: self.group.next()
            ).wait()
        )
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        XCTAssertLessThan(elapsed, 1.0, "Sampling took \(elapsed) seconds, expected < 1 second")

        threadUnblock.signal()
        threadDone.wait()

        let sampleData = try await ByteBuffer(
            contentsOf: FilePath("\(self.tempDirectory!)/samples.samples"),
            maximumSizeAllowed: .mebibytes(32)
        )
        XCTAssertGreaterThan(sampleData.readableBytes, 0, "Sample file should not be empty")
        let sampleString = String(buffer: sampleData)
        XCTAssertTrue(sampleString.contains("[SWIPR] SMPL"), "Sample file should contain sample data")
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

    // Opt-in: SWIPR_LONG_RUN_SECONDS=600 swift test --filter testLongRun
    func testLongRun() async throws {
        guard ProfileRecorderSampler.isSupportedPlatform,
            let seconds = ProcessInfo.processInfo.environment["SWIPR_LONG_RUN_SECONDS"].flatMap(Double.init)
        else {
            throw XCTSkip("set SWIPR_LONG_RUN_SECONDS to run the long run")
        }

        let keepRunning = ManagedAtomic<Bool>(true)
        let running = ManagedAtomic<Int>(0)
        func spawn(_ body: @escaping @Sendable () -> Void) {
            running.wrappingIncrement(ordering: .relaxed)
            Thread.detachNewThread {
                body()
                running.wrappingDecrement(ordering: .relaxed)
            }
        }
        // Short-lived threads with small stacks.
        spawn {
            while keepRunning.load(ordering: .relaxed) {
                let done = DispatchGroup()
                for _ in 0..<16 {
                    done.enter()
                    let thread = Thread {
                        _ = SWIPR_DEEP_STACK(10) {}
                        done.leave()
                    }
                    thread.stackSize = 64 << 10
                    thread.start()
                }
                done.wait()
            }
        }
        // Deep stacks that alternate between spinning and waiting at different depths, renaming themselves.
        for index in 0..<8 {
            spawn {
                var round = 0
                while keepRunning.load(ordering: .relaxed) {
                    round += 1
                    Thread.current.name = "swipr-run-\(index)-\(round % 3)"
                    _ = SWIPR_DEEP_STACK(20 + (index * 7 + round) % 200) {
                        SWIPR_BURST_SPIN(microseconds: 200)
                        usleep(UInt32(100 + round % 500))
                    }
                }
            }
        }
        // A thread that blocks and unblocks SIGPROF.
        spawn {
            var set = sigset_t()
            sigemptyset(&set)
            sigaddset(&set, SIGPROF)
            while keepRunning.load(ordering: .relaxed) {
                pthread_sigmask(SIG_BLOCK, &set, nil)
                usleep(300)
                pthread_sigmask(SIG_UNBLOCK, &set, nil)
                usleep(300)
            }
        }
        defer {
            keepRunning.store(false, ordering: .relaxed)
        }

        let end = DispatchTime.now().uptimeNanoseconds + UInt64(seconds * 1e9)
        var requests = 0
        var longest: UInt64 = 0
        while DispatchTime.now().uptimeNanoseconds < end {
            let start = DispatchTime.now().uptimeNanoseconds
            try await ProfileRecorderSampler.sharedInstance.requestSamples(
                outputFilePath: "\(self.tempDirectory!)/long-run.samples",
                failIfFileExists: false,
                count: 50 + requests % 150,
                timeBetweenSamples: .microseconds(Int64(requests % 3) * 500)
            )
            longest = max(longest, DispatchTime.now().uptimeNanoseconds - start)
            requests += 1
        }
        keepRunning.store(false, ordering: .relaxed)
        while running.load(ordering: .relaxed) > 0 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        print("long run: \(requests) requests, longest \(longest / 1_000_000) ms")
        XCTAssertLessThan(longest, 30_000_000_000, "a request stalled")
    }

    func testSamplingThreadsWithDeepStacks() async throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        let release = ConditionLock(value: 0)
        let ready = ManagedAtomic<Int>(0)
        let threadCount = 4
        for _ in 0..<threadCount {
            // 2000 frames of ~300 bytes: far past the unwinder's 128 frame and 128 KiB limits, across many pages.
            let thread = Thread {
                Thread.current.name = "swipr-deep"
                _ = SWIPR_DEEP_STACK(2000) {
                    ready.wrappingIncrement(ordering: .relaxed)
                    release.lock(whenValue: 1)
                    release.unlock()
                }
            }
            thread.stackSize = 8 << 20
            thread.start()
        }
        defer {
            release.lock()
            release.unlock(withValue: 1)
        }
        let startDeadline = DispatchTime.now() + .seconds(10)
        while ready.load(ordering: .relaxed) < threadCount {
            guard DispatchTime.now() < startDeadline else {
                XCTFail("deep-stack threads did not start")
                return
            }
            usleep(1000)
        }
        // On Darwin, main drops one thread off the list end per skipped thread; these newer threads take the drop.
        for _ in 0..<8 {
            Thread {
                release.lock(whenValue: 1)
                release.unlock()
            }.start()
        }

        let path = "\(self.tempDirectory!)/samples.samples"
        let ticks = 20
        try await ProfileRecorderSampler.sharedInstance.requestSamples(
            outputFilePath: path,
            count: ticks,
            timeBetweenSamples: .nanoseconds(0)
        )
        let lines = String(buffer: try await ByteBuffer(contentsOf: FilePath(path), maximumSizeAllowed: .mebibytes(64)))
            .split(separator: "\n")
        var deepSamples = 0
        var frames: Int? = nil
        for line in lines {
            if line.hasPrefix("[SWIPR] SMPL") {
                frames = line.contains(#""name": "swipr-deep""#) ? 0 : nil
            } else if line.hasPrefix("[SWIPR] STCK"), frames != nil {
                frames! += 1
            } else if line.hasPrefix("[SWIPR] DONE"), let depth = frames {
                deepSamples += 1
                XCTAssertGreaterThan(depth, 30)
                XCTAssertLessThanOrEqual(depth, 128)
                frames = nil
            }
        }
        XCTAssertGreaterThanOrEqual(deepSamples, ticks)
    }

    func testSamplingWhilstSmallStackThreadsAreCreatedAndDying() throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        let samples = ProfileRecorderSampler.sharedInstance.requestSamples(
            outputFilePath: "\(self.tempDirectory!)/samples.samples",
            count: 500,
            timeBetweenSamples: .microseconds(100),
            eventLoop: self.group.next()
        )
        let keepRunning = ManagedAtomic<Bool>(true)
        samples.whenComplete { _ in
            keepRunning.store(false, ordering: .relaxed)
        }
        while keepRunning.load(ordering: .relaxed) {
            let done = DispatchGroup()
            for _ in 0..<32 {
                done.enter()
                // Small stacks put the guard page and the stack top within a few frames of the sampled fp.
                let thread = Thread {
                    _ = SWIPR_DEEP_STACK(10) {}
                    done.leave()
                }
                thread.stackSize = 64 << 10
                thread.start()
            }
            done.wait()
        }
        XCTAssertNoThrow(try samples.wait())
    }

    func testWaitingThreadThatMovesToAnotherWaitIsResampled() async throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        // 0: waits in A, 1: moves to B, 2: exits.
        let stage = ConditionLock(value: 0)
        defer {
            stage.lock()
            stage.unlock(withValue: 2)
        }
        Thread.detachNewThread {
            Thread.current.name = "swipr-mover"
            SWIPR_WAIT_A(stage)
            SWIPR_WAIT_B(stage)
        }

        let path = "\(self.tempDirectory!)/samples.samples"
        func moverStacks() throws -> [[Substring]] {
            let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            var stacks: [[Substring]] = []
            var current: [Substring]? = nil
            for line in text.split(separator: "\n") {
                if line.hasPrefix("[SWIPR] SMPL") {
                    current = line.contains(#""name": "swipr-mover""#) ? [] : nil
                } else if line.hasPrefix("[SWIPR] STCK") {
                    current?.append(line)
                } else if line.hasPrefix("[SWIPR] DONE"), let stack = current {
                    stacks.append(stack)
                    current = nil
                }
            }
            return stacks
        }

        // The move lands mid-request, after the mover was sampled waiting in A, so a repeated stack would show A again.
        let request = Task {
            try await ProfileRecorderSampler.sharedInstance.requestSamples(
                outputFilePath: path,
                count: 60,
                timeBetweenSamples: .microseconds(500)
            )
        }
        let deadline = DispatchTime.now() + .seconds(5)
        while try moverStacks().count < 5 {
            if DispatchTime.now() > deadline {
                _ = try? await request.value
                XCTFail("mover sampled \(try moverStacks().count) times, needs 5")
                return
            }
            try await Task.sleep(nanoseconds: 100_000)
        }
        stage.lock()
        stage.unlock(withValue: 1)
        try await request.value

        let stacks = try moverStacks()
        XCTAssertNotEqual(stacks.first, stacks.last, "the stack after the move repeats the one before")
    }

    func testCPUModeSkipsWaitingThreads() async throws {
        guard ProfileRecorderSampler.isSupportedPlatform else {
            return
        }

        let idleThreads = NIOThreadPool(numberOfThreads: 32)
        idleThreads.start()
        defer {
            XCTAssertNoThrow(try idleThreads.syncShutdownGracefully())
        }
        let keepSpinning = ManagedAtomic<Bool>(true)
        defer {
            keepSpinning.store(false, ordering: .relaxed)
        }
        Thread.detachNewThread {
            while keepSpinning.load(ordering: .relaxed) {}
        }

        func sampleLines(mode: ProfileRecorderSamplingMode) async throws -> [Substring] {
            let path = "\(self.tempDirectory!)/samples-\(mode.rawValue).samples"
            try await ProfileRecorderSampler.sharedInstance.requestSamples(
                outputFilePath: path,
                count: 20,
                timeBetweenSamples: .nanoseconds(0),
                mode: mode
            )
            let data = try await ByteBuffer(contentsOf: FilePath(path), maximumSizeAllowed: .mebibytes(32))
            return String(buffer: data).split(separator: "\n")
        }

        let wall = try await sampleLines(mode: .wall)
        let cpu = try await sampleLines(mode: .cpu)
        XCTAssertTrue(cpu.contains { $0.hasPrefix("[SWIPR] CONF") && $0.contains(#""mode": "cpu""#) })
        let wallSamples = wall.filter { $0.hasPrefix("[SWIPR] SMPL") }.count
        let cpuSamples = cpu.filter { $0.hasPrefix("[SWIPR] SMPL") }.count
        XCTAssertGreaterThanOrEqual(wallSamples, 20 * 33, "every thread, every sample")
        XCTAssertGreaterThanOrEqual(cpuSamples, 1, "the spinning thread")
        XCTAssertLessThan(cpuSamples, wallSamples / 4, "the 32 idle threads are skipped")
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

    func testDemanglingWorks() async throws {
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

            let symbolizer = ProfileRecorderSampler._makeDefaultSymbolizer()
            try await NIOThreadPool.singleton.runIfActive { try symbolizer.start() }
            let demangledBytes = try await ProfileRecorderSampler.sharedInstance._withSamples(
                sampleCount: 1,
                timeBetweenSamples: .nanoseconds(0),
                format: .perfSymbolized,
                symbolizer: symbolizer,
                demangle: true,
                logger: self.logger
            ) { file in
                try await ByteBuffer(contentsOf: FilePath(file), maximumSizeAllowed: .mebibytes(16))
            }
            try await NIOThreadPool.singleton.runIfActive { try symbolizer.shutdown() }
            let demangled = String(buffer: demangledBytes)
            var fooSymbol = "s20ProfileRecorderTests25RECGONISABLE_FUNCTION_FOO"
            #if compiler(>=6.4)
            if #available(anyAppleOS 27, *) {
                fooSymbol = "ProfileRecorderTests.RECGONISABLE_FUNCTION_FOO("
            }
            #endif
            XCTAssert(demangled.contains(fooSymbol), "demangled foo missing: \(demangled)")
            XCTAssert(demangled.contains("RECGONISABLE_FUNCTION_QUUUX"), "demangled quuux missing: \(demangled)")
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

// Frames of 64-511 bytes, so a deep stack spans many pages.
@inline(never)
func SWIPR_DEEP_STACK(_ depth: Int, _ body: () -> Void) -> UInt8 {
    let frameBytes = 64 + (depth * 37) % 448
    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: frameBytes) { frame in
        frame.initialize(repeating: UInt8(truncatingIfNeeded: depth))
        if depth > 0 {
            frame[0] &+= SWIPR_DEEP_STACK(depth - 1, body)
        } else {
            body()
        }
        return frame[frameBytes - 1]
    }
}

@inline(never)
func SWIPR_BURST_SPIN(microseconds: Int) {
    let end = DispatchTime.now().uptimeNanoseconds + UInt64(microseconds) * 1_000
    while DispatchTime.now().uptimeNanoseconds < end {}
}

@inline(never)
func SWIPR_WAIT_A(_ stage: ConditionLock<Int>) {
    stage.lock(whenValue: 1)
    stage.unlock()
}

@inline(never)
func SWIPR_WAIT_B(_ stage: ConditionLock<Int>) {
    stage.lock(whenValue: 2)
    stage.unlock()
}
