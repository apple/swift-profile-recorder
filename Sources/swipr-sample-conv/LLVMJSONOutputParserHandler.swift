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
import NIOFoundationCompat
import Foundation
import _ProfileRecorderSampleConversion

// {"Address":"0x8acec","ModuleName":"/lib/libc6-prof/aarch64-linux-gnu/libc.so.6","Symbol":[{"Column":7,"Discriminator":0,"FileName":"./malloc/./malloc/malloc.c","FunctionName":"sysmalloc_mmap","Line":2485,"StartAddress":"0x8ac60","StartFileName":"./malloc/./malloc/malloc.c","StartLine":2420}]}
// {"Address":"0xffffffffffffffff","Error":{"Message":"No such file or directory"},"ModuleName":"/ignore/errors/about/this"}
// {"Address":"0xffffffffffffffff","ModuleName":"/ignore/errors/about/this","Symbol":[]}
struct LLVMSymbolizerJSONOutput: Codable & Sendable {
    struct GoodSymbol: Sendable {
        var functionName: String
        var offset: UInt
        var sourceFile: Optional<String>
        var sourceLine: Optional<Int>
    }

    struct Symbol: Codable & Sendable {
        var Column: Int?
        var Discriminator: Int?
        var FileName: String?
        var FunctionName: String?
        var Line: Int?
        var StartAddress: String?
        var StartFileName: String?
        var StartLine: Int?

        func goodSymbol(address: UInt) -> GoodSymbol? {
            guard let functionName = self.FunctionName else { return nil }

            let startAddress = self.StartAddress.flatMap({ UInt(hexDigits: $0) }) ?? address
            let offset = address >= startAddress ? address - startAddress : 0

            return GoodSymbol(
                functionName: functionName.isEmpty
                    ? "<unknown in \(self.FileName.flatMap { $0.isEmpty ? nil : $0 } ?? "empty")>" : functionName,
                offset: offset,
                sourceFile: (self.FileName?.isEmpty ?? true) ? nil : self.FileName,
                sourceLine: self.Line
            )
        }
    }
    struct Error: Codable & Sendable {
        var Message: String?
    }
    var Address: String?
    var ModuleName: String?
    var Symbol: [Symbol]?
    var Error: Error?
}

final internal class LLVMJSONOutputParserHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = SymbolisedStackFrame

    private var accumulation: [ByteBuffer] = []
    private let jsonDecoder = JSONDecoder()

    internal func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = Self.unwrapInboundIn(data)
        var outputFrames: [SymbolisedStackFrame.SingleFrame] = []
        defer {
            context.fireChannelRead(Self.wrapInboundOut(SymbolisedStackFrame(allFrames: outputFrames)))
        }

        let decoded: LLVMSymbolizerJSONOutput
        do {
            decoded = try self.jsonDecoder.decode(LLVMSymbolizerJSONOutput.self, from: data)
        } catch {
            fputs(
                """
                WARNING: failed to parse llvm-symbolizer JSON output (\(error)), got '\(data)'\n
                """,
                stderr
            )
            return
        }
        guard let addressString = decoded.Address, let address = UInt(hexDigits: addressString) else {
            fputs(
                """
                WARNING: unexpected llvm-symbolizer JSON output, got '\(data)'\n
                """,
                stderr
            )
            return
        }
        guard let symbolList = decoded.Symbol, !symbolList.isEmpty else {
            outputFrames.append(
                SymbolisedStackFrame.SingleFrame(
                    address: address,
                    functionName: "<unknown-unset>",
                    functionOffset: 0,
                    library: decoded.ModuleName,
                    vmap: nil,
                    file: nil,
                    line: nil
                )
            )
            return
        }

        for symbol in symbolList {
            var output = SymbolisedStackFrame.SingleFrame(
                address: address,
                functionName: "<unknown-unset>",
                functionOffset: 0,
                library: decoded.ModuleName ?? "unknown-unset",
                vmap: nil,
                file: nil,
                line: nil
            )

            if let goodSymbol = symbol.goodSymbol(address: address) {
                output.functionName = goodSymbol.functionName
                output.functionOffset = goodSymbol.offset
                output.line = goodSymbol.sourceLine
                output.file = goodSymbol.sourceFile
            }

            outputFrames.append(output)
        }
    }
}

extension Optional {
    mutating func setIfNonNil(_ newValue: Wrapped?) {
        guard let newValue = newValue else {
            return
        }
        self = newValue
    }
}

extension UInt {
    init?(hexDigits: String) {
        let result: Self?
        if hexDigits.hasPrefix("0x") {
            result = Self(hexDigits.dropFirst(2), radix: 16)
        } else {
            result = Self(hexDigits)
        }
        guard let result = result else {
            return nil
        }
        self = result
    }
}
