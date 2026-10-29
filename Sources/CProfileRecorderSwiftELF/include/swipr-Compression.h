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

//===--- Compression.h - C decls for compression libraries ------*- C++ -*-===//
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
// Includes and definitions to allow us to use the compression libraries
// (zlib, zstd and liblzma) in the backtracing module.
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_BACKTRACING_COMPRESSION_H
#define SWIFT_BACKTRACING_COMPRESSION_H

#include <stdint.h>
#include <stdlib.h>

// Right now, we're soft linking to zlib/zstd/liblzma, so that users don't
// need it installed (but if they try to do something that requires it,
// they'll see an error message).
//
// As a result, we've grabbed copies of the relevant definitions here so
// that we don't need to install the -dev packages in order to build Swift.

#if SWIFT_BACKTRACE_STATIC_ZLIB
#include "zlib.h"
#else
// This is the version we took the SWIPR_z_stream structure from
#define internal_SWIPR_ZLIB_VERSION "1.2.11"

#define internal_SWIPR_Z_OK 0
#define internal_SWIPR_Z_STREAM_END 1

#define internal_SWIPR_Z_NO_FLUSH 0

typedef struct SWIPR_z_stream_s {
  uint8_t *next_in;
  unsigned avail_in;
  unsigned long total_in;

  uint8_t *next_out;
  unsigned avail_out;
  unsigned long total_out;

  const char *msg;
  struct internal_state *state;

  void (*zalloc)(void *, unsigned, unsigned);
  void (*zfree)(void *, void *);
  void *opaque;

  int data_type;

  unsigned long adler;
  unsigned long reserved;
} SWIPR_z_stream;

typedef SWIPR_z_stream *SWIPR_z_streamp;
#endif

#if SWIFT_BACKTRACE_STATIC_ZSTD
#include "zstd.h"
#else
typedef struct SWIPR_ZSTD_inBuffer_s {
  const void *src;
  size_t size;
  size_t pos;
} SWIPR_ZSTD_inBuffer;

typedef struct SWIPR_ZSTD_outBuffer_s {
  void *dst;
  size_t size;
  size_t pos;
} SWIPR_ZSTD_outBuffer;
#endif

#if SWIFT_BACKTRACE_STATIC_LIBLZMA
#include "lzma.h"
#else
typedef enum {
  internal_SWIPR_LZMA_OK = 0,
  internal_SWIPR_LZMA_STREAM_END = 1,
  internal_SWIPR_LZMA_NO_CHECK = 2,
  internal_SWIPR_LZMA_UNSUPPORTED_CHECK = 3,
  internal_SWIPR_LZMA_GET_CHECK = 4,
  internal_SWIPR_LZMA_MEM_ERROR = 5,
  internal_SWIPR_LZMA_MEMLIMIT_ERROR = 6,
  internal_SWIPR_LZMA_FORMAT_ERROR = 7,
  internal_SWIPR_LZMA_OPTIONS_ERROR = 8,
  internal_SWIPR_LZMA_DATA_ERROR = 9,
  internal_SWIPR_LZMA_BUF_ERROR = 10,
  internal_SWIPR_LZMA_PROG_ERROR = 11,
} SWIPR_lzma_ret;

typedef enum {
  internal_SWIPR_LZMA_RUN = 0,
  internal_SWIPR_LZMA_SYNC_FLUSH = 1,
  internal_SWIPR_LZMA_FULL_FLUSH = 2,
  internal_SWIPR_LZMA_FULL_BARRIER = 4,
  internal_SWIPR_LZMA_FINISH = 3
} SWIPR_lzma_action;

typedef enum {
  internal_SWIPR_LZMA_RESERVED_ENUM = 0,
} SWIPR_lzma_reserved_enum;

typedef struct {
  void *(*alloc)(void *, size_t, size_t);
  void (*free)(void *, void *);
  void *opaque;
} SWIPR_lzma_allocator;

typedef struct SWIPR_lzma_internal_s SWIPR_lzma_internal;

typedef struct {
  const uint8_t *next_in;
  size_t avail_in;
  uint64_t total_in;

  uint8_t *next_out;
  size_t avail_out;
  uint64_t total_out;

  const SWIPR_lzma_allocator *allocator;

  SWIPR_lzma_internal *internal;

  void *reserved_ptr1;
  void *reserved_ptr2;
  void *reserved_ptr3;
  void *reserved_ptr4;
  uint64_t reserved_int1;
  uint64_t reserved_int2;
  size_t reserved_int3;
  size_t reserved_int4;
  SWIPR_lzma_reserved_enum reserved_enum1;
  SWIPR_lzma_reserved_enum reserved_enum2;
} SWIPR_lzma_stream;

#define internal_SWIPR_LZMA_STREAM_INIT {0}
#endif

#ifdef __cplusplus
namespace SWIPRswift {
namespace SWIPRruntime {
#endif

// The Swift importer can't cope with complex macros; it will do inline
// functions, however.
static inline SWIPR_lzma_stream SWIPR_lzma_stream_init() {
  return (SWIPR_lzma_stream)internal_SWIPR_LZMA_STREAM_INIT;
}
static inline SWIPR_z_stream SWIPR_zlib_stream_init() {
  return (SWIPR_z_stream){ 0 };
}

#ifdef __cplusplus
} // namespace SWIPRruntime
} // namespace SWIPRswift
#endif

#endif // SWIFT_BACKTRACING_COMPRESSION_H
