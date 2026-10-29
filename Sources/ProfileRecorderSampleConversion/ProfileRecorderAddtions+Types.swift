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
    public var line: Int {
        get { self.lineRange?.lowerBound ?? 0 }
        set { self.lineRange = Self.singleValueRange(newValue) }
    }

    /// The column number.
    public var column: Int {
        get { self.columnRange?.lowerBound ?? 0 }
        set { self.columnRange = Self.singleValueRange(newValue) }
    }

    /// The line range.
    var lineRange: Range<Int>?

    /// The column range.
    var columnRange: Range<Int>?

    /// Construct a SourceLocation with a single line/column
    init(path: String, line: Int, column: Int = 0) {
        self.path = path
        self.lineRange = Self.singleValueRange(line)
        self.columnRange = Self.singleValueRange(column)
    }

    /// Construct a SourceLocation with a line/column range
    init(path: String, lineRange: Range<Int>?, columnRange: Range<Int>?) {
        self.path = path
        self.lineRange = lineRange
        self.columnRange = columnRange
    }

    /// Provide a textual description.
    public var description: String {
        var formatted = self.path
        if let lineRange = self.lineRange {
            formatted += ":\(Self.format(lineRange))"
            if let columnRange = self.columnRange {
                formatted += ":\(Self.format(columnRange))"
            }
        }
        return formatted
    }

    private static func singleValueRange(_ value: Int) -> Range<Int>? {
        return value > 0 ? value..<value : nil
    }

    private static func format(_ range: Range<Int>) -> String {
        if range.lowerBound == range.upperBound {
            return "\(range.lowerBound)"
        } else {
            return "\(range.lowerBound)-\(range.upperBound)"
        }
    }
}

/// The vendored code reports recoverable DWARF parsing problems through the Swift runtime, we ignore them.
func swift_reportWarning(_ flags: UInt32, _ message: String) {}

#if !compiler(>=6.2)
// The vendored PDB support needs Swift 6.2, these stubs provide what `DefaultSymbolLocator` uses. PDB files are only
// used on Windows anyway.

final class PDBFile: SymbolSource {
    var signature: [UInt8] = []
    var age: UInt32 = 0

    init?(path: String) {
        return nil
    }

    func lookupSymbol(address: Address) -> Symbol? {
        return nil
    }

    func sourceLocation(for address: Address) -> SourceLocation? {
        return nil
    }

    func inlineCallSites(at address: Address) -> [CallSiteInfo] {
        return []
    }
}

final class PDBCache {
    static var threadLocal: PDBCache {
        return PDBCache()
    }

    func lookup(path: String?) -> PDBFile? {
        return nil
    }
}
#endif
