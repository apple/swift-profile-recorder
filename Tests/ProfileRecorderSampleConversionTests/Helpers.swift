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

import _ProfileRecorderSampleConversion
import Logging

final class FakeSymbolizer: Symbolizer {
    var description: String {
        return "FakeSymbolizer"
    }

    func start() throws {
    }

    func symbolise(
        fileVirtualAddressIP: UInt,
        library: DynamicLibMapping,
        logger: Logger
    ) throws -> SymbolisedStackFrame {
        return SymbolisedStackFrame(
            allFrames: [
                SymbolisedStackFrame.SingleFrame(
                    address: fileVirtualAddressIP,
                    functionName: "fake",
                    functionOffset: 5,
                    library: "libfoo",
                    vmap: library
                )
            ]
        )
    }

    func shutdown() throws {
    }
}
