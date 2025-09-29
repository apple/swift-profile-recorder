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

//===--- MemoryReader.swift -----------------------------------*- swift -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
//  Provides the ability to read memory, both in the current process and
//  remotely.
//
//===----------------------------------------------------------------------===//



#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import ucrt
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#endif

#if os(macOS)

#endif

@_spi(MemoryReaders) public protocol MemoryReader {
  typealias Address = UInt64
  typealias Size = UInt64

  /// Fill the specified buffer with data from the specified location in
  /// the source.
  func fetch(from address: Address,
             into buffer: UnsafeMutableRawBufferPointer) throws

  /// Fill the specified buffer with data from the specified location in
  /// the source.
  func fetch<T>(from address: Address,
                into buffer: UnsafeMutableBufferPointer<T>) throws

  /// Write data from the specified location in the source through a pointer
  func fetch<T>(from addr: Address,
                into pointer: UnsafeMutablePointer<T>) throws

  /// Fetch an array of Ts from the specified location in the source
  func fetch<T>(from addr: Address, count: Int, as: T.Type) throws -> [T]

  /// Fetch a T from the specified location in the source
  func fetch<T>(from addr: Address, as: T.Type) throws -> T

  /// Fetch a NUL terminated string from the specified location in the source
  func fetchString(from addr: Address) throws -> String?

  /// Fetch a fixed-length string from the specified location in the source
  func fetchString(from addr: Address, length: Int) throws -> String?
}

extension MemoryReader {

  public func fetch<T>(from address: Address,
                       into buffer: UnsafeMutableBufferPointer<T>) throws {
    try fetch(from: address, into: UnsafeMutableRawBufferPointer(buffer))
  }

  public func fetch<T>(from addr: Address,
                       into pointer: UnsafeMutablePointer<T>) throws {
    try fetch(from: addr,
              into: UnsafeMutableBufferPointer(start: pointer, count: 1))
  }

  public func fetch<T>(from addr: Address, count: Int, as: T.Type) throws -> [T] {
    let array = try Array<T>(unsafeUninitializedCapacity: count){
      buffer, initializedCount in

      try fetch(from: addr, into: buffer)

      initializedCount = count
    }

    return array
  }

  public func fetch<T>(from addr: Address, as: T.Type) throws -> T {
    return try withUnsafeTemporaryAllocation(of: T.self, capacity: 1) { buf in
      try fetch(from: addr, into: buf)
      return buf[0]
    }
  }

  public func fetchString(from addr: Address) throws -> String? {
    var bytes: [UInt8] = []
    var ptr = addr
    while true {
      let ch = try fetch(from: ptr, as: UInt8.self)
      if ch == 0 {
        break
      }
      bytes.append(ch)
      ptr += 1
    }

    return String(decoding: bytes, as: UTF8.self)
  }

  public func fetchString(from addr: Address, length: Int) throws -> String? {
    let bytes = try fetch(from: addr, count: length, as: UInt8.self)
    return String(decoding: bytes, as: UTF8.self)
  }
}
