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
// This file has been adjusted for ProfileRecorder, originally of the Swift.org open source project
// swift-format-ignore-file

#if compiler(>=6.2)
//===--- PDBFile+SymbolSource.swift - PDB support for Swift ---------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Implements the SymbolSource protocol for PDB files.
//
//===----------------------------------------------------------------------===//



extension PDBFile: SymbolSource {
  func lookupSymbol(
    address: SymbolSource.Address
  ) -> SymbolSource.Symbol? {
    guard let symbolLookup = lookup(address: UInt32(address)) else {
      return nil
    }

    return SymbolSource.Symbol(name: symbolLookup.rawName ?? symbolLookup.name,
                               offset: Int(symbolLookup.offset),
                               size: nil)
  }

  func sourceLocation(
    for address: SymbolSource.Address
  ) -> SymbolSource.SourceLocation? {
    guard let symbolLookup = lookup(address: UInt32(address)) else {
      return nil
    }

    guard let location = symbolLookup.sourceLocation else {
      return nil
    }

    return SymbolSource.SourceLocation(
      path: location.filename,
      lineRange: location.lineRange,
      columnRange: location.columnRange
    )
  }

  func inlineCallSites(
    at address: SymbolSource.Address
  ) -> Array<SymbolSource.CallSiteInfo> {
    return []
  }
}
#endif
