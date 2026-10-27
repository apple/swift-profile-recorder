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
import NIOCore
import ProfileRecorder
import Synchronization

// Up to 100 typical, 900 extreme; must stay under SWIPR_MAX_MUTATOR_THREADS (1024), which main does not check.
private let threadCounts = [10, 50, 100, 900]

// On Linux activeProcessorCount counts every core, including ones this process is not allowed to run on.
private let usableCores: Int = {
    #if os(Linux)
    // "Cpus_allowed:\t<hex mask, comma separated>"
    if let status = try? String(contentsOfFile: "/proc/self/status", encoding: .utf8),
        let mask = status.split(separator: "\n").first(where: { $0.hasPrefix("Cpus_allowed:") })
    {
        return mask.dropFirst("Cpus_allowed:".count).reduce(0) {
            $0 + (Int(String($1), radix: 16) ?? 0).nonzeroBitCount
        }
    }
    #endif
    return ProcessInfo.processInfo.activeProcessorCount
}()

// 10% of threads on CPU, at most half the cores: more spinners make scheduler delays show up as pause.
private func busyThreads(of threads: Int) -> Int {
    max(1, min(threads / 10, usableCores / 2))
}

// Gaps above this in a busy thread's clock reads count as time it was held by the sampler, as in sysjitter.
private let stallThresholdNanoseconds: UInt64 = 10_000
private let busyThreadsStalledNanoseconds = Atomic<Int>(0)
private let samplerTimePerTick = BenchmarkMetric.custom(
    "Sampler time per tick (us)",
    polarity: .prefersSmaller,
    useScalingFactor: false
)
private let pausePerBusyThreadPerTick = BenchmarkMetric.custom(
    "Pause per busy thread per tick (us)",
    polarity: .prefersSmaller,
    useScalingFactor: false
)

// Long stacks: 30-60 frames of 64-511 bytes each, so a walk crosses stack pages.
@inline(never)
private func deepStack(_ depth: Int, _ body: () -> Void) -> UInt8 {
    let frameBytes = 64 + (depth * 37) % 448
    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: frameBytes) { frame in
        frame.initialize(repeating: UInt8(truncatingIfNeeded: depth))
        if depth > 0 {
            frame[0] &+= deepStack(depth - 1, body)
        } else {
            body()
        }
        return frame[frameBytes - 1]
    }
}

private func stackDepth(ofThread index: Int) -> Int {
    30 + index % 31
}

// Busy threads first, so they are sampled first; returns once all are in place, so the first capture lists them all.
private func spawnThreads(idle: Int, busy: Int) {
    let started = Atomic<Int>(0)
    for index in 0..<busy {
        Thread.detachNewThread {
            _ = deepStack(stackDepth(ofThread: index)) {
                started.add(1, ordering: .relaxed)
                var last = DispatchTime.now().uptimeNanoseconds
                while true {
                    let now = DispatchTime.now().uptimeNanoseconds
                    if now - last > stallThresholdNanoseconds {
                        busyThreadsStalledNanoseconds.wrappingAdd(Int(now - last), ordering: .relaxed)
                    }
                    last = now
                }
            }
        }
    }
    for index in 0..<idle {
        Thread.detachNewThread {
            _ = deepStack(stackDepth(ofThread: index)) {
                started.add(1, ordering: .relaxed)
                DispatchSemaphore(value: 0).wait()
            }
        }
    }
    while started.load(ordering: .relaxed) < idle + busy {
        usleep(1000)
    }
}

// A regular file as in real use: /dev/null gets a larger stdio buffer and hides the cost of writes.
private func sample(_ ticks: Int, everyMilliseconds interval: Int64) async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent("swipr-bench-\(UUID()).raw").path
    defer {
        try? FileManager.default.removeItem(atPath: path)
    }
    try await ProfileRecorderSampler.sharedInstance.requestSamples(
        outputFilePath: path,
        count: ticks,
        timeBetweenSamples: .milliseconds(interval)
    )
}

// Ticks per pause iteration, at the README's 10ms interval.
private let pauseTicks = 20

// Stall time the busy threads see while `body` runs, per busy thread per tick.
private func pauseBenchmark(_ name: String, idle: Int, busy: Int, _ body: @escaping () async throws -> Void) {
    Benchmark(
        name,
        configuration: .init(
            metrics: [pausePerBusyThreadPerTick],
            // Up to ~0.6 s per iteration at 900 threads.
            maxDuration: .seconds(15),
            setup: { spawnThreads(idle: idle, busy: busy) }
        )
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            let stalledBefore = busyThreadsStalledNanoseconds.load(ordering: .relaxed)
            try await body()
            let stalled = busyThreadsStalledNanoseconds.load(ordering: .relaxed) - stalledBefore
            benchmark.measurement(pausePerBusyThreadPerTick, stalled / (pauseTicks * busy) / 1_000)
        }
    }
}

let benchmarks: @Sendable () -> Void = {
    // The sampler samples NIO's threads too; one per core would make thread counts differ between machines.
    NIOSingletons.groupLoopCountSuggestion = 1

    Benchmark.defaultConfiguration = .init(
        // Plain microseconds; automatic units silently switch large rows to thousands.
        units: [samplerTimePerTick: .count, pausePerBusyThreadPerTick: .count],
        warmupIterations: 1,
        maxDuration: .seconds(5),
        maxIterations: 50
    )

    // The tool runs each benchmark in its own process, sorted by name, hence the zero padding.
    for threads in threadCounts {
        let busy = busyThreads(of: threads)
        let label = "\(String(format: "%04d", threads)) threads (\(busy) busy)"

        // Back-to-back ticks; wall time includes per-request setup (file open, image map) spread over the ticks.
        Benchmark(
            "cost: \(label)",
            configuration: .init(
                metrics: [samplerTimePerTick],
                setup: { spawnThreads(idle: threads - busy, busy: busy) }
            )
        ) { benchmark in
            // 11 at 900 threads keeps an iteration near 0.3 s, so maxDuration still allows ~15 iterations.
            let ticks = min(100, 10_000 / threads)
            for _ in benchmark.scaledIterations {
                let start = DispatchTime.now().uptimeNanoseconds
                try await sample(ticks, everyMilliseconds: 0)
                let elapsed = Int(DispatchTime.now().uptimeNanoseconds - start)
                benchmark.measurement(samplerTimePerTick, elapsed / ticks / 1_000)
            }
        }

        pauseBenchmark("pause at 100 Hz: \(label)", idle: threads - busy, busy: busy) {
            try await sample(pauseTicks, everyMilliseconds: 10)
        }
    }

    // No sampler: stalls from the scheduler and interrupts alone, the floor under the pause rows.
    for busy in Set(threadCounts.map(busyThreads(of:))).sorted() {
        pauseBenchmark("pause at 100 Hz: no sampler, \(busy) busy", idle: 0, busy: busy) {
            try await Task.sleep(for: .milliseconds(10 * pauseTicks))
        }
    }
}
