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

#if canImport(Glibc)
@preconcurrency import Glibc // Sendability of stdout/stderr/..., needs to be at the top of the file
#endif
import Foundation

func swift_reportWarning(_ dunno: Int, _ message: String) {
    fputs("WARNING: \(message)\n", stderr)
}

extension Substring.UTF8View {
    /// This is a very terrible JSON parser that should just about be able to parse a `StackFrame`
    ///
    /// - note: We are ignoring the stack pointer, so the stack pointer field will always be 0.
    public func attemptFastParseStackFrame() -> StackFrame? {
        enum State {
            case beginning
            case ipWaitingFor0x
            case ipStartRange(String.Index, String.Index?)

            var isWaitingFor0x: Bool {
                if case .ipWaitingFor0x = self {
                    return true
                }
                return false
            }
        }
        var state: State = .beginning
        let bytes = self
        loop: for byteIndex in bytes.indices {
            let byte = bytes[byteIndex]
            switch byte {
            case UInt8(ascii: "\""):
                if case .ipStartRange(let start, .none) = state {
                    state = .ipStartRange(start, byteIndex)
                    break loop
                }
                continue
            case UInt8(ascii: " "), UInt8(ascii: ":"), UInt8(ascii: "{"), UInt8(ascii: "}"),
                UInt8(ascii: "p"):
                // example line:
                // {"ip": "0x18fe24c08", "sp": "0x1702a6fe0"}
                // we ignore everything that's not an 'i', an 's' or hex digit like
                // __i_____0x18fe24c08____s_____0x1702a6fe0
                continue
            case UInt8(ascii: "i"):
                state = .ipWaitingFor0x
            case UInt8(ascii: "0")...UInt8(ascii: "9"),
                UInt8(ascii: "a")...UInt8(ascii: "f"),
                UInt8(ascii: "A")...UInt8(ascii: "F"):
                // ignore
                continue
            case UInt8(ascii: "x") where state.isWaitingFor0x:
                state = .ipStartRange(bytes.index(after: byteIndex), nil)
                break
            default:
                continue
            }
        }

        if case .ipStartRange(let start, .some(let end)) = state {
            guard let string = String(self[start..<end]), let ip = UInt(string, radix: 16) else {
                return nil
            }
            return StackFrame(instructionPointer: ip, stackPointer: 0)
        } else {
            return nil
        }
    }
}
