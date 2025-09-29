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

/// Represents a location in source code.
///
/// The information in this structure comes from compiler-generated
/// debug information and may not correspond to the current state of
/// the filesystem --- it might even hold a path that only works
/// from an entirely different machine.
public struct SourceLocation: CustomStringConvertible, Sendable, Hashable {
    /// The path of the source file.
    public var path: String

    /// The line number.
    public var line: Int

    /// The column number.
    public var column: Int

    /// Provide a textual description.
    public var description: String {
        if column > 0 && line > 0 {
            return "\(path):\(line):\(column)"
        } else if line > 0 {
            return "\(path):\(line)"
        } else {
            return path
        }
    }
}
