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
//===--- Module.swift - PDB support for Swift -----------------------------===//
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
// Defines a structure used to hold information about a module.
//
//===----------------------------------------------------------------------===//



struct Module {
  var name: String
  var object: String
  var streamNumber: Int?
  var cbSyms: Int
  var cbLines: Int
  var cbFpo: Int
  var cbC13Lines: Int
  var files: [String] = []
}
#endif
