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

//===--- Compression.swift - Data compression for ELF images --------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Defines the compressed image sources, which are used to access compressed
// data from ELF images.
//
// There are three different compression formats we might have to interact
// with, namely zlib (deflate), zstd and LZMA.  We don't implement the
// decompression algorithms here, but rather we will try to use zlib,
// zstd and liblzma respectively.
//
// We support two different modes; one is where the compression libraries
// have been statically linked with us, in which case we can just call them;
// the other is where we will try to load them with `dlopen()`.  We do this
// so as to avoid a hard dependency on them in the runtime.
//
//===----------------------------------------------------------------------===//



#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import ucrt
import WinSDK
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
import CProfileRecorderSwiftELF
import CProfileRecorderSwiftELF

enum CompressedImageSourceError: Error {
  case unboundedImageSource
  case outOfRangeFetch(UInt64, Int)
  case badCompressedData
  case unsupportedFormat
  case libraryNotFound(String)
  case outputOverrun
}

let SWIPR_zlib_stream_init = CProfileRecorderSwiftELF.SWIPR_zlib_stream_init
let SWIPR_lzma_stream_init = CProfileRecorderSwiftELF.SWIPR_lzma_stream_init

/// The maximum size of blob we're prepared to decompress
fileprivate let maxUncompressedSize = 1 << 30 // 1GB

// .. CompressedStream .........................................................

protocol CompressedStream {
  typealias InputSource = () throws -> UnsafeRawBufferPointer
  typealias OutputSink = (_ used: UInt, _ done: Bool) throws
    -> UnsafeMutableRawBufferPointer?

  func decompress(input: InputSource, output: OutputSink) throws -> UInt
}

// .. Compression library bindings .............................................

#if canImport(Darwin)
private var lzmaHandle = dlopen("liblzma.dylib", RTLD_LAZY)
private var zlibHandle = dlopen("libz.dylib", RTLD_LAZY)
private var zstdHandle = dlopen("libzstd.dylib", RTLD_LAZY)
#elseif os(Linux)
private var lzmaHandle = dlopen("liblzma.so.5", RTLD_LAZY)
private var zlibHandle = dlopen("libz.so.1", RTLD_LAZY)
private var zstdHandle = dlopen("libzstd.so.1", RTLD_LAZY)
#elseif os(Windows)
private var lzmaHandle = LoadLibraryA("liblzma.dll")
private var zlibHandle = LoadLibraryA("zlib1.dll")
private var zstdHandle = LoadLibraryA("libzstd.dll")
#endif

#if os(Windows)
private func symbol<T>(_ handle: HMODULE?, _ name: String) -> T? {
  guard let handle = handle, let result = GetProcAddress(handle, name) else {
    return nil
  }
  return unsafeBitCast(result, to: T.self)
}
#else
private func symbol<T>(_ handle: UnsafeMutableRawPointer?, _ name: String) -> T? {
  guard let handle = handle, let result = dlsym(handle, name) else {
    return nil
  }
  return unsafeBitCast(result, to: T.self)
}
#endif

private enum CompressionSym {
  static let lzma_stream_decoder: (
    @convention(c) (UnsafeMutablePointer<SWIPR_lzma_stream>,
                    UInt64, UInt32) -> SWIPR_lzma_ret)?
    = symbol(lzmaHandle, "lzma_stream_decoder")

  static let lzma_code: (@convention(c) (UnsafeMutablePointer<SWIPR_lzma_stream>,
                                         SWIPR_lzma_action) -> SWIPR_lzma_ret)?
    = symbol(lzmaHandle, "lzma_code")

  static let lzma_end: (@convention(c) (UnsafeMutablePointer<SWIPR_lzma_stream>) -> ())?
    = symbol(lzmaHandle, "lzma_end")

  static let inflateInit_: (@convention(c) (SWIPR_z_streamp,
                                            UnsafePointer<CChar>, CInt) -> CInt)?
    = symbol(zlibHandle, "inflateInit_")

  static func inflateInit(_ stream: SWIPR_z_streamp) -> CInt {
    return inflateInit_!(stream, internal_SWIPR_ZLIB_VERSION, CInt(MemoryLayout<SWIPR_z_stream>.size))
  }

  static let inflate: (@convention(c) (SWIPR_z_streamp, CInt) -> CInt)?
    = symbol(zlibHandle, "inflate")

  static let inflateEnd: (@convention(c) (SWIPR_z_streamp) -> CInt)?
    = symbol(zlibHandle, "inflateEnd")

  static let ZSTD_createDStream: (
    @convention(c) () -> UnsafeMutableRawPointer?)?
    = symbol(zstdHandle, "ZSTD_createDStream")

  static let ZSTD_freeDStream: (
    @convention(c) (UnsafeMutableRawPointer) -> UInt)?
    = symbol(zstdHandle, "ZSTD_freeDStream")

  static let ZSTD_decompressStream: (
    @convention(c) (UnsafeMutableRawPointer,
                    UnsafeMutablePointer<SWIPR_ZSTD_outBuffer>,
                    UnsafeMutablePointer<SWIPR_ZSTD_inBuffer>) -> UInt)?
    = symbol(zstdHandle, "ZSTD_decompressStream")

  static let ZSTD_isError: (@convention(c) (UInt) -> UInt)?
    = symbol(zstdHandle, "ZSTD_isError")
}

// .. zlib (deflate) ...........................................................

enum ZLibError: Error {
  case decodeError(CInt)
}

struct ZLibStream: CompressedStream {
  init() {}

  func decompress(input: InputSource, output: OutputSink) throws -> UInt {

    if zlibHandle == nil {
      throw CompressedImageSourceError.libraryNotFound("libz")
    }

    var stream = SWIPR_zlib_stream_init()

    let ret = CompressionSym.inflateInit(&stream)
    if ret != internal_SWIPR_Z_OK {
      throw ZLibError.decodeError(ret)
    }
    defer {
      _ = CompressionSym.inflateEnd!(&stream)
    }

    var outputBufferSize = UInt(0)
    while true {
      if stream.avail_in == 0 {
        let buffer = try input()

        // Not really mutable; this is just an issue with z_const
        stream.next_in = UnsafeMutablePointer(
          mutating: buffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
        )
        stream.avail_in = CUnsignedInt(buffer.count)
      }

      if stream.avail_out == 0 {
        guard let buffer = try output(outputBufferSize, false) else {
          throw CompressedImageSourceError.outputOverrun
        }

        stream.next_out = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
        stream.avail_out = CUnsignedInt(buffer.count)
        outputBufferSize = UInt(buffer.count)
      }

      let ret = CompressionSym.inflate!(&stream, internal_SWIPR_Z_NO_FLUSH)

      if ret == internal_SWIPR_Z_STREAM_END {
        _ = try output(outputBufferSize - UInt(stream.avail_out), true)
        return UInt(stream.total_out)
      }

      if ret != internal_SWIPR_Z_OK {
        throw ZLibError.decodeError(ret)
      }
    }
  }
}

// .. zstd .....................................................................

enum ZStdError: Error {
  case unableToCreateStream
  case decodeError(UInt)
}

struct ZStdStream: CompressedStream {
  init() {}

  func decompress(input: InputSource, output: OutputSink) throws -> UInt {

    if zstdHandle == nil {
      throw CompressedImageSourceError.libraryNotFound("libzstd")
    }

    guard let stream = CompressionSym.ZSTD_createDStream!() else {
      throw ZStdError.unableToCreateStream
    }
    defer {
      _ = CompressionSym.ZSTD_freeDStream!(stream)
    }

    var inBuffer = SWIPR_ZSTD_inBuffer(src: nil, size: 0, pos: 0)
    var outBuffer = SWIPR_ZSTD_outBuffer(dst: nil, size: 0, pos: 0)
    var totalOutput = UInt(0)

    while true {
      if inBuffer.size == inBuffer.pos {
        let buffer = try input()

        inBuffer.src = buffer.baseAddress
        inBuffer.size = buffer.count
        inBuffer.pos = 0
      }

      if outBuffer.size == outBuffer.pos {
        let byteCount = UInt(outBuffer.pos)

        totalOutput += byteCount

        guard let buffer = try output(byteCount, false) else {
          throw CompressedImageSourceError.outputOverrun
        }

        outBuffer.dst = buffer.baseAddress
        outBuffer.size = buffer.count
        outBuffer.pos = 0
      }

      let ret = CompressionSym.ZSTD_decompressStream!(stream, &outBuffer, &inBuffer)

      if ret == 0 {
        totalOutput += UInt(outBuffer.pos)
        _ = try output(UInt(outBuffer.pos), true)
        return totalOutput
      }

      if CompressionSym.ZSTD_isError!(ret) != 0 {
        throw ZStdError.decodeError(ret)
      }
    }
  }
}


// .. LZMA .....................................................................

enum LZMAError: Error {
  case decodeError(SWIPR_lzma_ret)
}

struct LZMAStream: CompressedStream {
  private var memlimit: UInt64
  private var flags: UInt32

  init(memlimit: UInt64 = ~UInt64(0), flags: UInt32 = 0) {
    self.memlimit = memlimit
    self.flags = flags
  }

  func decompress(input: InputSource, output: OutputSink) throws -> UInt {

    if lzmaHandle == nil {
      throw CompressedImageSourceError.libraryNotFound("liblzma")
    }

    var stream = SWIPR_lzma_stream_init()

    let ret = CompressionSym.lzma_stream_decoder!(&stream, memlimit, flags)
    if ret != internal_SWIPR_LZMA_OK {
      throw LZMAError.decodeError(ret)
    }
    defer {
      CompressionSym.lzma_end!(&stream)
    }

    var outputBufferSize = UInt(0)
    while true {
      if stream.avail_in == 0 {
        let buffer = try input()
        stream.next_in = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
        stream.avail_in = buffer.count
      }

      if stream.avail_out == 0 {
        guard let buffer = try output(outputBufferSize, false) else {
          throw CompressedImageSourceError.outputOverrun
        }

        stream.next_out = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
        stream.avail_out = buffer.count
        outputBufferSize = UInt(buffer.count)
      }

      let ret = CompressionSym.lzma_code!(&stream, internal_SWIPR_LZMA_RUN)

      if ret == internal_SWIPR_LZMA_STREAM_END {
        _ = try output(outputBufferSize - UInt(stream.avail_out), true)
        return UInt(stream.total_out)
      }

      if ret != internal_SWIPR_LZMA_OK {
        throw LZMAError.decodeError(ret)
      }
    }
  }
}

// .. Image Sources ............................................................


fileprivate func decompress<S: CompressedStream>(
  stream: S,
  source: ImageSource,
  offset: Int,
  output: inout ImageSource
) throws {
  let totalBytes = try stream.decompress(
    input: {
      () throws -> UnsafeRawBufferPointer in

      return UnsafeRawBufferPointer(rebasing: source.bytes[offset...])
    },
    output: {
      (used: UInt, done: Bool) throws -> UnsafeMutableRawBufferPointer? in

      if used == 0 {
        return output.unusedBytes
      } else {
        return nil
      }
    }
  )
  output.used(bytes: Int(totalBytes))
}


fileprivate func decompressChunked<S: CompressedStream>(
  stream: S,
  source: ImageSource,
  offset: Int,
  output: inout ImageSource
) throws {
  let bufSize = 65536
  let outputBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufSize,
                                                            alignment: 16)
  defer {
    outputBuffer.deallocate()
  }

  let _ = try stream.decompress(
    input: {
      () throws -> UnsafeRawBufferPointer in

      return UnsafeRawBufferPointer(rebasing: source.bytes[offset...])
    },
    output: {
      (used: UInt, done: Bool) throws -> UnsafeMutableRawBufferPointer? in

      output.append(
        bytes: UnsafeRawBufferPointer(rebasing: outputBuffer[..<Int(used)])
      )
      if !done {
        return outputBuffer
      } else {
        return nil
      }
    }
  )
}


extension ImageSource {
  @_specialize(kind: full, where Traits == Elf32Traits)
  @_specialize(kind: full, where Traits == Elf64Traits)
  init<Traits: ElfTraits>(elfCompressedImageSource source: ImageSource,
                          traits: Traits.Type) throws {
    if source.bytes.count < MemoryLayout<Traits.Chdr>.size {
      throw CompressedImageSourceError.badCompressedData
    }

    let rawChdr = try source.fetch(from: 0, as: Traits.Chdr.self)
    let chdr: Traits.Chdr
    switch rawChdr.ch_type {
      case .internal_SWIPR_ELFCOMPRESS_ZLIB.byteSwapped, .internal_SWIPR_ELFCOMPRESS_ZSTD.byteSwapped:
        chdr = rawChdr.byteSwapped
      default:
        chdr = rawChdr
    }

    guard let uncompressedSize = Int(exactly: chdr.ch_size),
          uncompressedSize <= maxUncompressedSize else {
      throw CompressedImageSourceError.badCompressedData
    }

    self.init(capacity: uncompressedSize, isMappedImage: false, path: nil)

    switch chdr.ch_type {
      case .internal_SWIPR_ELFCOMPRESS_ZLIB:
        try decompress(stream: ZLibStream(),
                       source: source, offset: MemoryLayout<Traits.Chdr>.stride,
                       output: &self)
      case .internal_SWIPR_ELFCOMPRESS_ZSTD:
        try decompress(stream: ZStdStream(),
                       source: source, offset: MemoryLayout<Traits.Chdr>.stride,
                       output: &self)
      default:
        throw CompressedImageSourceError.unsupportedFormat
    }
  }

  init(gnuCompressedImageSource source: ImageSource) throws {
    if source.bytes.count < 12 {
      throw CompressedImageSourceError.badCompressedData
    }

    let magic = try source.fetch(from: 0, as: UInt32.self)
    let rawUncompressedSize = try source.fetch(from: 4, as: UInt64.self)
    let uncompressedSize: UInt64
    switch magic {
      case 0x42494c5a: // BILZ
        uncompressedSize = rawUncompressedSize.byteSwapped
      case 0x5a4c4942: // ZLIB
        uncompressedSize = rawUncompressedSize
      default:
        throw CompressedImageSourceError.badCompressedData
    }

    guard let uncompressed = Int(exactly: uncompressedSize),
          uncompressed <= maxUncompressedSize else {
      throw CompressedImageSourceError.badCompressedData
    }

    self.init(capacity: uncompressed, isMappedImage: false, path: nil)

    try decompress(stream: ZLibStream(),
                   source: source, offset: 12,
                   output: &self)
  }

  init(lzmaCompressedImageSource source: ImageSource) throws {
    self.init(isMappedImage: false, path: nil)

    try decompressChunked(stream: LZMAStream(),
                          source: source, offset: 0,
                          output: &self)
  }
}
