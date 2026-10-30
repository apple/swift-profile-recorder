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

//===--- SymbolLocator.swift - Symbol file finding for Swift --------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Defines a protocol for a symbol locator that, when handed an image, can
// determine where the symbols for that image might be located.
//
//===----------------------------------------------------------------------===//





struct SymbolLocationSymbol: Sendable, Hashable, Equatable {
  var name: String
  var offset: Int
  var size: Int?
}

struct SymbolLocationCallSiteInfo: Sendable, Hashable, Equatable {
  var rawName: String?
  var name: String?
  var location: _ProfileRecorderSampleConversion.SourceLocation
}

/// A `SymbolSource` is a place where we can fetch information about symbols.
/// It *may* be an image of some sort, or it could be some other kind of
/// thing (e.g. for Windows binaries, a PDB file).
protocol SymbolSource {
  typealias Address = UInt64

  typealias Symbol = SymbolLocationSymbol
  typealias CallSiteInfo = SymbolLocationCallSiteInfo
  typealias SourceLocation = _ProfileRecorderSampleConversion.SourceLocation

  func lookupSymbol(address: Address) -> Symbol?
  func sourceLocation(for address: Address) -> SourceLocation?
  func inlineCallSites(at address: Address) -> Array<CallSiteInfo>
}

protocol SymbolLocator {

  typealias Image = SymbolLoader.Image
  typealias ImageFormat = SymbolLoader.ImageFormat

  func find(image: any Image) -> String?
  func findSymbols(for image: any Image) -> (any SymbolSource)?
  func findSymbols(for image: any Image,
                   format: ImageFormat) -> (any SymbolSource)?

}

extension SymbolLocator {
  func findSymbols(for image: any Image) -> (any SymbolSource)? {
    return findSymbols(for: image, format: .auto)
  }
}

/*
extension Backtrace.Image: SymbolLocator.Image {
  var uuid: [UInt8]? { uniqueID }
  var age: UInt32? { nil }
}
*/

struct SymbolLoader {

  protocol Image {
    var name: String? { get }
    var path: String? { get }
    var uuid: [UInt8]? { get }
    var age: UInt32? { get }
  }

  enum ImageFormat {
    case auto
    case elf
    case peCoff
  }

  func loadSymbols(for image: any Image,
                   from path: String) -> (any SymbolSource)? {
    let pdbCache = PDBCache.threadLocal

    if let pdbFile = pdbCache.lookup(path: path) {
      if pdbFile.signature == image.uuid && pdbFile.age == image.age {
        return pdbFile
      }
    }

    let elfCache = ElfImageCache.threadLocal

    if let result = elfCache.lookup(path: path) {
      switch result {
        case let .elf32Image(elfImage):
          if let uuid = image.uuid, uuid != elfImage.uuid {
            return nil
          }
          return elfImage
        case let .elf64Image(elfImage):
          if let uuid = image.uuid, uuid != elfImage.uuid {
            return nil
          }
          return elfImage
      }
    }

    let peCache = PeImageCache.threadLocal

    if let coffImage = peCache.lookup(path: path) {
      if coffImage.getDwarfSection(.debugLine) != nil {
        return coffImage
      }
    }

    return nil
  }
}
