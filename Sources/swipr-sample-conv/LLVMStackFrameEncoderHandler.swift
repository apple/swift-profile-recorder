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

import NIO
import Foundation
import _ProfileRecorderSampleConversion
import Logging

struct LLVMSymbolizerQuery: Sendable {
    var address: UInt
    var library: DynamicLibMapping
}

final internal class LLVMSymbolizerEncoderHandler: ChannelOutboundHandler {
    typealias OutboundIn = LLVMSymbolizerQuery
    typealias OutboundOut = ByteBuffer

    private let fileManager: FileManager
    private let logger: Logger

    internal init(logger: Logger) {
        self.fileManager = FileManager.default
        self.logger = logger
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let query = Self.unwrapOutboundIn(data)

        var buffer = context.channel.allocator.buffer(capacity: 256)

        if self.fileManager.fileExists(atPath: query.library.path) {
            buffer.writeString("\"")
            buffer.writeString(query.library.path)
            buffer.writeString("\" 0x")
            buffer.writeString(String(query.address, radix: 16))
        } else {
            buffer.writeString("/file/not/found\(query.library.path) 0x")
            buffer.writeString(String(query.address, radix: 16))
        }
        buffer.writeString("\n")
        logger.trace("emitting llvm-symbolizer requst", metadata: ["request": "\(String(buffer: buffer))"])
        context.write(Self.wrapOutboundOut(buffer), promise: promise)
    }
}
