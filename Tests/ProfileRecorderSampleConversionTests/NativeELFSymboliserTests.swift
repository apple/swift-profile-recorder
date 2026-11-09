//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift Profile Recorder project authors
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

@testable import _ProfileRecorderSampleConversion

final class NativeELFSymboliserTests: XCTestCase {
    func testFailedLoadsAreCached() throws {
        let logger = Logger(label: "\(Self.self)")
        let symbolizer = NativeELFSymboliser()
        try symbolizer.start()
        defer {
            XCTAssertNoThrow(try symbolizer.shutdown())
        }
        let library = DynamicLibMapping(
            path: "/does-not-exist/libfoo.so",
            architecture: "x86_64",
            segmentSlide: 0x1000,
            segmentStartAddress: 0x2000,
            segmentEndAddress: 0x3000
        )

        for fileVirtualAddressIP: UInt in [0x1234, 0x1567] {
            let expected = SymbolisedStackFrame(
                allFrames: [
                    SymbolisedStackFrame.SingleFrame(
                        address: fileVirtualAddressIP,
                        functionName: "unknown-load-failed @ 0x\(String(fileVirtualAddressIP, radix: 16))",
                        functionOffset: 0,
                        library: nil,
                        vmap: library
                    )
                ]
            )
            let actual = try symbolizer.symbolise(
                fileVirtualAddressIP: fileVirtualAddressIP,
                library: library,
                logger: logger
            )
            XCTAssertEqual(expected, actual)
            XCTAssertEqual(1, symbolizer.elfSourceCache.count)
        }
    }
}
