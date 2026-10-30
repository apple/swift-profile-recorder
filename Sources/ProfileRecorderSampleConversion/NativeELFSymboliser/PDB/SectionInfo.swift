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
//===--- FunctionInfo.swift - PDB support for Swift -----------------------===//
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
// Defines a structure used to hold information about a function.
//
//===----------------------------------------------------------------------===//



struct SectionCharacteristics: OptionSet, Sendable {
  typealias RawValue = UInt32

  var rawValue: UInt32

  init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  static let noPad
    = SectionCharacteristics(rawValue: 0x00000008)
  static let code
    = SectionCharacteristics(rawValue: 0x00000020)
  static let initializedData
    = SectionCharacteristics(rawValue: 0x00000040)
  static let uninitializedData
    = SectionCharacteristics(rawValue: 0x00000080)
  static let noDeferSpeculativeExecution
    = SectionCharacteristics(rawValue: 0x00004000)
  static let gpRelative
    = SectionCharacteristics(rawValue: 0x00008000)
  static let hasExtendedRelocations
    = SectionCharacteristics(rawValue: 0x01000000)
  static let discardable
    = SectionCharacteristics(rawValue: 0x02000000)
  static let notCached
    = SectionCharacteristics(rawValue: 0x04000000)
  static let notPaged
    = SectionCharacteristics(rawValue: 0x08000000)
  static let shared
    = SectionCharacteristics(rawValue: 0x10000000)
  static let executable
    = SectionCharacteristics(rawValue: 0x20000000)
  static let readable
    = SectionCharacteristics(rawValue: 0x40000000)
  static let writable
    = SectionCharacteristics(rawValue: 0x80000000)
}

struct SectionInfo {
  var name: String
  var virtualAddress: UInt32
  var size: UInt32
  var characteristics: SectionCharacteristics
}
#endif
