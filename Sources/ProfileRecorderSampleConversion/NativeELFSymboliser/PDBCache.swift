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
//===--- PDBCache.swift - PDB support for Swift ---------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Provides a per-thread PDB cache that improves efficiency when taking
// multiple backtraces by avoiding loading PDBs multiple times.
//
//===----------------------------------------------------------------------===//



#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import WinSDK
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Provides a per-thread image cache for PDB processing.  This means
/// if you take multiple backtraces from a thread, you won't load the same
/// image multiple times.
final class PDBCache {
  var cache: [String: PDBFile] = [:]

  func purge() {
    cache = [:]
  }

  func lookup(path: String?) -> PDBFile? {
    guard let path = path else {
      return nil
    }
    if let image = cache[path] {
      return image
    }
    if let image = PDBFile(path: path) {
      cache[path] = image
      return image
    }
    return nil
  }

  #if os(Windows)
  private static var dwTlsIndex: DWORD = {
    let dwNdx = TlsAlloc()
    if dwNdx == TLS_OUT_OF_INDEXES {
      fatalError("Unable to allocate TSD for PDBCache")
    }
    return dwNdx
  }()
  #else
  private static var key: pthread_key_t = {
    var theKey = pthread_key_t()
    let err = pthread_key_create(
      &theKey,
      { rawPtr in
        let ptr = Unmanaged<PDBCache>.fromOpaque(
          notMutable(notOptional(rawPtr))
        )
        ptr.release()
      }
    )
    if err != 0 {
      fatalError("Unable to create TSD key for PDBCache")
    }
    return theKey
  }()
  #endif

  static var threadLocal: PDBCache {
    #if os(Windows)
    guard let rawPtr = TlsGetValue(dwTlsIndex) else {
      let cache = Unmanaged<PDBCache>.passRetained(PDBCache())
      TlsSetValue(dwTlsIndex, cache.toOpaque())
      return cache.takeUnretainedValue()
    }
    #else
    guard let rawPtr = pthread_getspecific(key) else {
      let cache = Unmanaged<PDBCache>.passRetained(PDBCache())
      pthread_setspecific(key, cache.toOpaque())
      return cache.takeUnretainedValue()
    }
    #endif
    let cache = Unmanaged<PDBCache>.fromOpaque(rawPtr)
    return cache.takeUnretainedValue()
  }
}
#endif
