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

import ArgumentParser
import ProfileRecorder
import Dispatch
import Foundation
import ProfileRecorderServer
import Logging

@main
struct ProfileRecorderMiniDemo: ParsableCommand & Sendable {
    @Flag(inversion: .prefixedNo, help: "Should we run a blocking function?")
    var blocking: Bool = false

    @Flag(inversion: .prefixedNo, help: "Should we burn a bit of CPU?")
    var burnCPU: Bool = true

    @Flag(inversion: .prefixedNo, help: "Should we burn do a bunch of Array.appends?")
    var arrayAppends: Bool = false

    @Flag(inversion: .prefixedNo, help: "Start profile recording server?")
    var profilingServer: Bool = false

    @Option(help: "How many samples?")
    var sampleCount: Int = 100

    @Option(help: "How many ms between samples?")
    var msBetweenSamples: Int64 = 10

    @Option(help: "Where to write the samples to?")
    var output: String = "-"

    @Option(help: "How many iterations?")
    var iterations: Int = 10

    @Option(help: "Run multi-threaded")
    var threads: Int = 1

    func run() throws {
        let logger = Logger(label: "swipr-mini-demo")
        var profilingServerTask: Task<Void, any Error>? = nil
        if self.profilingServer {
            profilingServerTask = Task {
                do {
                    try await ProfileRecorderServer(
                        configuration: try await .parseFromEnvironment()
                    ).run(logger: logger)
                } catch {
                    logger.error("failed to start profile recording server", metadata: ["error": "\(error)"])
                }
            }
        }
        defer {
            profilingServerTask?.cancel()
        }
        ProfileRecorderSampler.sharedInstance.requestSamples(
            outputFilePath: self.output,
            failIfFileExists: false,
            count: self.sampleCount,
            timeBetweenSamples: .milliseconds(
                self.msBetweenSamples
            ),
            queue: DispatchQueue.global(),
            { result in
                print("- collected samples: \(result)")
            }
        )

        print("""
              STARTING to \(self.iterations) iterations \
              \(self.burnCPU ? ", burn CPU" : "") \
              \(self.arrayAppends ? ", array appends" : "") \
              \(self.blocking ? ", blocking" : "")
              """
        )
        let queue = DispatchQueue.global()
        for _ in 0..<self.iterations {
            if self.threads > 1 {
                let g = DispatchGroup()
                for _ in 0..<self.threads {
                    queue.async(group: g) {
                        self.runIteration()
                    }
                }
                g.wait()
            } else {
                self.runIteration()
            }
        }
        print("DONE")
        fflush(stdout)
    }

    func runIteration() {
        if self.arrayAppends {
            var xs: [Int] = []
            for x in 0..<4_000_000 {
                xs.append(x)
            }
            precondition(xs.count == xs.count - 1 + 1)
        }
        if self.burnCPU {
            doBurnCPU()
        }
        if self.blocking {
            func hideBlocking() {
                Thread.sleep(forTimeInterval: 0.2)
            }
            hideBlocking()
        }
    }
}

func doBurnCPU() {
    #if DEBUG
    let notRotated = Array(1...400)
    #else
    let notRotated = Array(1...10_000)
    #endif
    var rotated = notRotated
    rotated.rotate(toStartAt: 1)

    while notRotated != rotated {
        rotated.rotate(toStartAt: 1)
    }
}

extension Array {
    mutating func rotate(toStartAt index: Int) {
        let tmp = self[0..<index]
        self[0...] = self[index...]
        self.append(contentsOf: tmp)
    }
}
