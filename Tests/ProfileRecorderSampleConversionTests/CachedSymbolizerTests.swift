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

import Logging
import XCTest
import NIO

@testable import ProfileRecorderSampleConversion

final class CachedSymbolizerTests: XCTestCase {
    private var symbolizer: CachedSymbolizer! = nil
    private var underlyingSymbolizer: FakeSymbolizer! = nil
    private var logger: Logger! = nil

    func testSymbolisingFrameThatIsFound() throws {
        let actual = try self.symbolizer.symbolise(StackFrame(instructionPointer: 0x2345, stackPointer: .max))
        let expected = SymbolisedStackFrame(
            allFrames: [
                SymbolisedStackFrame.SingleFrame(
                    address: 0x1345,
                    functionName: "fake",
                    functionOffset: 5,
                    library: "libfoo",
                    vmap: DynamicLibMapping(
                        path: "/lib/libfoo.so",
                        architecture: "arm64",
                        segmentSlide: 0x1000,
                        segmentStartAddress: 0x2000,
                        segmentEndAddress: 0x3000
                    )
                )
            ]
        )
        XCTAssertEqual(expected, actual)
    }

    func testSymbolisingFrameThatIsNotFound() throws {
        let actual = try self.symbolizer.symbolise(StackFrame(instructionPointer: 0x3000, stackPointer: .max))
        let expected = SymbolisedStackFrame(allFrames: [
            SymbolisedStackFrame.SingleFrame(
                address: 0x3000,
                functionName: "unknown @ 0x3000",
                functionOffset: 0,
                library: nil,
                vmap: nil
            )
        ])
        XCTAssertEqual(expected, actual)
    }

    // MARK: - Setup/teardown
    override func setUpWithError() throws {
        self.logger = Logger(label: "\(Self.self)")
        self.logger.logLevel = .info

        self.underlyingSymbolizer = FakeSymbolizer()
        try self.underlyingSymbolizer!.start()
        self.symbolizer = CachedSymbolizer(
            configuration: SymbolizerConfiguration(perfScriptOutputWithFileLineInformation: false),
            symbolizer: self.underlyingSymbolizer!,
            dynamicLibraryMappings: [
                DynamicLibMapping(
                    path: "/lib/libfoo.so",
                    architecture: "arm64",
                    segmentSlide: 0x1000,
                    segmentStartAddress: 0x2000,
                    segmentEndAddress: 0x3000
                )
            ],
            group: .singletonMultiThreadedEventLoopGroup,
            logger: self.logger
        )
    }

    override func tearDown() {
        XCTAssertNoThrow(try self.underlyingSymbolizer!.shutdown())
        self.underlyingSymbolizer = nil
        self.symbolizer = nil
        self.logger = nil
    }

    // MARK: - Helpers
    func instructionPointerFixup() -> Int {
        #if arch(arm) || arch(arm64)
        // Known fixed-width instruction format
        return 4
        #else
        // Unknown, subtract 1
        return 1
        #endif
    }
}
