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
#endif
import NIO
import ProfileRecorderSampleConversion

final internal class LLVMOutputParserHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = SymbolisedStackFrame

    private var accumulation: [ByteBuffer] = []

    internal func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = Self.unwrapInboundIn(data)

        if data.readableBytes == 0 {
            // done, process now
            var frames: [SymbolisedStackFrame.SingleFrame] = []

            if self.accumulation.count < 3 {
                fputs(
                    """
                    WARNING: unexpected llvm-symbolizer text output (expected 1 + 2*n lines), \
                    ignoring all: \(self.accumulation)\n
                    """,
                    stderr
                )
            } else {
                var remaining = self.accumulation[...]
                let address = UInt(hexDigits: String(buffer: remaining.removeFirst())) ?? 0xdeadbef

                frames.reserveCapacity(remaining.count / 2)
                while !remaining.isEmpty {
                    guard remaining.count >= 2 else {
                        fputs(
                            """
                            WARNING: unexpected llvm-symbolizer text output (expected 1 + 2*n lines), \
                            ignoring last: \(self.accumulation)\n
                            """,
                            stderr
                        )
                        break
                    }
                    let functionName = String(buffer: remaining.removeFirst())
                    let fileLineColumn = String(buffer: remaining.removeFirst())
                    let fileLineColumnSplit = fileLineColumn.split(separator: ":", maxSplits: 2)
                    frames.append(
                        SymbolisedStackFrame.SingleFrame(
                            address: address,
                            functionName: functionName,
                            functionOffset: 0,
                            library: nil,
                            vmap: nil,
                            file: String(fileLineColumnSplit.first ?? "unknown"),
                            line: fileLineColumnSplit.dropFirst().first.flatMap { Int($0) }
                        )
                    )

                }
            }

            self.accumulation.removeAll()
            let out = SymbolisedStackFrame(allFrames: frames)
            context.fireChannelRead(Self.wrapInboundOut(out))
        } else {
            if self.accumulation.isEmpty && String(buffer: data).starts(with: "CODE ") {
                let address = UInt(hexDigits: String(String(buffer: data).dropFirst(5))) ?? 0xdeadcaf
                let out = SymbolisedStackFrame(
                    allFrames: [
                        .init(
                            address: address,
                            functionName: "0x" + String(address, radix: 16),
                            functionOffset: 0,
                            library: "somewhere",
                            vmap: nil,
                            file: nil,
                            line: nil
                        )
                    ]
                )

                context.fireChannelRead(Self.wrapInboundOut(out))
            } else {
                self.accumulation.append(data)
            }
        }
    }
}
