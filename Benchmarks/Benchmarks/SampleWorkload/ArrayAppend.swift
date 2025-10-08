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
import Dispatch
import Foundation

public struct ArrayAppend {
    var iterations: Int
    var blocking: Bool
    var threads: Int

    public init(
        iterations: Int = 4_000_000,
        blocking: Bool = false,
        threads: Int = 1
    ) {
        self.iterations = iterations
        self.blocking = blocking
        self.threads = threads
    }

    private func runIteration() {
        var xs: [Int] = []
        for x in 0..<iterations {
            xs.append(x)
        }
        blackHole(xs)
        if blocking {
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    public func run() {
        if threads > 1 {
            let g = DispatchGroup()
            let queue = DispatchQueue.global()
            for _ in 0..<threads {
                queue.async(group: g) {
                    self.runIteration()
                }
            }
            g.wait()
        } else {
            runIteration()
        }
    }
}
