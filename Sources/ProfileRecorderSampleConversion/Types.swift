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

public struct Sample {
    public var sampleHeader: SampleHeader
    public var stack: [StackFrame]

    public var pid: Int {
        return self.sampleHeader.pid
    }

    public var tid: Int {
        return self.sampleHeader.tid
    }

    public var timeSec: Int {
        return self.sampleHeader.timeSec
    }

    public var timeNSec: Int {
        return self.sampleHeader.timeNSec
    }

    public var threadName: String {
        return self.sampleHeader.name
    }

    public var threadState: String? {
        return self.sampleHeader.state
    }

    public init(sampleHeader: SampleHeader, stack: [StackFrame]) {
        self.sampleHeader = sampleHeader
        self.stack = stack
    }
}
