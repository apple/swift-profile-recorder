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

import XCTest
import _ProfileRecorderSampleConversion

final class SampleConversionTests: XCTestCase {
    func testBasicExample() {
        let line = #"{"ip": "0x18fe24c08", "sp": "0x1702a6fe0"}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0x1_8fe2_4c08, stackPointer: 0), actual)
    }

    func testZero() {
        let line = #"{"ip": "0x0", "sp": "0x1702a6fe0"}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0x0, stackPointer: 0), actual)
    }

    func testNoSpaces() {
        let line = #"{"ip":"0x18fe24c08","sp":"0x1702a6fe0"}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0x1_8fe2_4c08, stackPointer: 0), actual)
    }

    func testOrder() {
        let line = #"{"sp":"0x1702a6fe0","ip":"0x18fe24c08"}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0x1_8fe2_4c08, stackPointer: 0), actual)
    }

    func testExtraFieldsOrder() {
        let line = #"{"sp":"0x1702a6fe0","unknown-field":"hello","ip":"0x18fe24c08"}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0x1_8fe2_4c08, stackPointer: 0), actual)
    }

    func testSimpleCase() {
        let line = #"{"ip":"0x18fe24c08","sp":"0x1702a6fe0"}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0x1_8fe2_4c08, stackPointer: 0), actual)
    }

    func testIpFirst() {
        let line = #"{"ip":"0xABCDEF","sp":"0x1702a6fe0"}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0xABCDEF, stackPointer: 0), actual)
    }

    func testIpLast() {
        let line = #"{"sp":"0x1234","thread":"42","flags":"0x9","ip":"0xCAFEBABE"}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0xCAFE_BABE, stackPointer: 0), actual)
    }

    func testIpWithSpaces() {
        let line = #"  {   "ip" :   "0xDEAD10CC" , "sp":"0x1702a6fe0" }  "#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0xDEAD_10CC, stackPointer: 0), actual)
    }

    func testIpMixedFields() {
        let line = #"{"foo":1,"bar":true,"ip":"0x12345678","baz":[1,2,3]}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0x1234_5678, stackPointer: 0), actual)
    }

    func testIpEmbeddedInText() {
        let line = #"{"message":"before","ip":"0xFEEDFACE","after":"something"}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0xFEED_FACE, stackPointer: 0), actual)
    }

    func testIpUpperLowerMix() {
        let line = #"{"ip":"0xDeadBeef"}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0xDEAD_BEEF, stackPointer: 0), actual)
    }

    func testIpOnly() {
        let line = #"{"ip":"0x11111111"}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0x1111_1111, stackPointer: 0), actual)
    }

    func testIPWithEscapedString() {
        let line = #"{"comment":"the ip is \"secret\"","ip":"0xFACEB00C"}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(StackFrame(instructionPointer: 0xFACE_B00C, stackPointer: 0), actual)
    }

    func testNoIPAtAll() {
        let line = #"{"comment":"the ip is \"secret\""}"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(nil, actual)
    }

    func testPartialIP() {
        let line = #"{"comment":"the ip is \"secret\"", "ip": "0x123"#[...]
        let actual = line.utf8.attemptFastParseStackFrame()
        XCTAssertEqual(nil, actual)
    }
}
