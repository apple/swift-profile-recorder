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
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Logging
import NIOExtras

public final class _ProfileRecorderFakeSymbolizer: Symbolizer {
    public init() {}

    public func start() throws {}

    public func symbolise(
        fileVirtualAddressIP: UInt,
        library: DynamicLibMapping,
        logger: Logger
    ) throws -> SymbolisedStackFrame {
        return SymbolisedStackFrame(
            allFrames: [
                SymbolisedStackFrame.SingleFrame(
                    address: fileVirtualAddressIP,
                    functionName: "FakeType.fakeFun\(fileVirtualAddressIP / 10000)()",
                    functionOffset: fileVirtualAddressIP % 10000,
                    library: nil,
                    vmap: library
                )
            ]
        )

    }

    public func shutdown() throws {}

    public var description: String {
        return "FakeSymbolizer"
    }
}
