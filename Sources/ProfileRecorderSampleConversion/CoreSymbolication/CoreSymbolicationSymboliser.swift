//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
import Darwin
import Logging
import NIOConcurrencyHelpers

public final class CoreSymbolicationSymboliser: Symbolizer & Sendable {

    private let cache: NIOLockedValueBox<[String: CSSymbolicatorRef]> = NIOLockedValueBox([:])
    
    public init() {}

    public func start() throws {}
    
    public func symbolise(
        fileVirtualAddressIP: UInt, // the offset to the instruction WITHOUT bass address
        library: DynamicLibMapping,
        logger: Logging.Logger
    ) throws -> SymbolisedStackFrame {
        
        func makeFailed(_ why: String = "") -> SymbolisedStackFrame {
            return SymbolisedStackFrame(
                allFrames: [SymbolisedStackFrame.SingleFrame(
                    address: fileVirtualAddressIP,
                    functionName: "unknown-missing\(why) @ 0x\(String(fileVirtualAddressIP, radix: 16))",
                    functionOffset: 0,
                    library: nil,
                    vmap: library,
                    file: nil,
                    line: nil
                )]
            )
        }
        
        var symbolicator: CSSymbolicatorRef
        // acquire lock and check if symbolicator for this library is already cached
        // if so increment ref count so it's unaffected by release else where
        let cachedSymbolicator: CSSymbolicatorRef? = self.cache.withLockedValue { cache in
            return cache[library.path].map { CSRetain($0) }
        }
        
        if cachedSymbolicator != nil {
            symbolicator = cachedSymbolicator!
        } else {
            // otherwise create new symbolicator
            symbolicator = SymbolicatorCreateWithDynamicLibMapping(library)
            self.cache.withLockedValue({ cache in
                // if it is now cached we use that instead
                if cache[library.path] != nil {
                    CSRelease(symbolicator)
                    symbolicator = CSRetain(cache[library.path]!)
                } else {
                    if cache.count > 1_000 { // free up cache if full
                        let old = cache.remove(at: cache.startIndex)
                        CSRelease(old.value)
                    }
                    cache[library.path] = CSRetain(symbolicator)
                }
            })
        }
        
        if CSIsNull(symbolicator){
            return makeFailed("-symbolicator")
        }
        
        defer {
            CSRelease(symbolicator)
        }
        
        let symbolOwner = CSSymbolicatorGetSymbolOwner(symbolicator)
        if CSIsNull(symbolOwner){
            return makeFailed("-symbol-owner")
        }

        // CS expects offset into library + base address from CS
        let baseAddress = CSSymbolOwnerGetBaseAddress(symbolOwner)
        let offset = fileVirtualAddressIP + library.segmentSlide - library.segmentStartAddress
        
        let expectedIP = vm_address_t(offset) + baseAddress

        let symbol = CSSymbolicatorGetSymbolWithAddressAtTime(symbolicator, expectedIP)
        if CSIsNull(symbol){
            return makeFailed("-symbol")
        }
        let name = CSSymbolGetMangledName(symbol) ?? "unknown"

        return SymbolisedStackFrame(
            allFrames: [SymbolisedStackFrame.SingleFrame(
                address: fileVirtualAddressIP,
                functionName: name,
                functionOffset: UInt(expectedIP),
                library: nil,
                vmap: library,
                file: nil,
                line: nil
            )]
        )
    }
    
    public func shutdown() throws {
        let allSyms = self.cache.withLockedValue { cache in
            let allValues = cache.values
            cache.removeAll()
            return allValues
        }
        for syms in allSyms {
            CSRelease(syms)
        }
    }
    
    public var description: String {
        return "CoreSymbolicationSymboliser"
    }
}
#endif
