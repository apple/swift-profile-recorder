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

//===--- Elf.swift - ELF support for Swift --------------------------------===//
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
// Defines various ELF structures and provides types for working with ELF
// images on disk and in memory.
//
//===----------------------------------------------------------------------===//

// ###FIXME: We shouldn't really use String for paths.



#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import ucrt
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
import CProfileRecorderSwiftELF

// .. Use *our* Elf definitions ................................................

// On Linux there is an <elf.h> header that can be dragged in via Glibc, which
// contains slightly different definitions that don't work so well with Swift.
// We don't want those, so we're using C++ interop and putting ours in the
// swift::runtime namespace.

// This means we need a lot of typealiases, and also aliases for untyped
// constants.

typealias SWIPR_Elf_Byte   = CProfileRecorderSwiftELF.SWIPR_Elf_Byte
typealias SWIPR_Elf_Half   = CProfileRecorderSwiftELF.SWIPR_Elf_Half
typealias SWIPR_Elf_Word   = CProfileRecorderSwiftELF.SWIPR_Elf_Word
typealias SWIPR_Elf_Xword  = CProfileRecorderSwiftELF.SWIPR_Elf_Xword
typealias SWIPR_Elf_Sword  = CProfileRecorderSwiftELF.SWIPR_Elf_Sword
typealias SWIPR_Elf_Sxword = CProfileRecorderSwiftELF.SWIPR_Elf_Sxword

typealias SWIPR_Elf32_Byte   = CProfileRecorderSwiftELF.SWIPR_Elf32_Byte
typealias SWIPR_Elf32_Half   = CProfileRecorderSwiftELF.SWIPR_Elf32_Half
typealias SWIPR_Elf32_Word   = CProfileRecorderSwiftELF.SWIPR_Elf32_Word
typealias SWIPR_Elf32_Sword  = CProfileRecorderSwiftELF.SWIPR_Elf32_Sword

typealias SWIPR_Elf64_Byte   = CProfileRecorderSwiftELF.SWIPR_Elf64_Byte
typealias SWIPR_Elf64_Half   = CProfileRecorderSwiftELF.SWIPR_Elf64_Half
typealias SWIPR_Elf64_Word   = CProfileRecorderSwiftELF.SWIPR_Elf64_Word
typealias SWIPR_Elf64_Xword  = CProfileRecorderSwiftELF.SWIPR_Elf64_Xword
typealias SWIPR_Elf64_Sword  = CProfileRecorderSwiftELF.SWIPR_Elf64_Sword
typealias SWIPR_Elf64_Sxword = CProfileRecorderSwiftELF.SWIPR_Elf64_Sxword

typealias SWIPR_Elf_Ehdr_Type    = CProfileRecorderSwiftELF.SWIPR_Elf_Ehdr_Type
typealias SWIPR_Elf_Ehdr_Machine = CProfileRecorderSwiftELF.SWIPR_Elf_Ehdr_Machine
typealias SWIPR_Elf_Ehdr_Version = CProfileRecorderSwiftELF.SWIPR_Elf_Ehdr_Version

let internal_SWIPR_EI_MAG0       = CProfileRecorderSwiftELF.internal_SWIPR_EI_MAG0
let internal_SWIPR_EI_MAG1       = CProfileRecorderSwiftELF.internal_SWIPR_EI_MAG1
let internal_SWIPR_EI_MAG2       = CProfileRecorderSwiftELF.internal_SWIPR_EI_MAG2
let internal_SWIPR_EI_MAG3       = CProfileRecorderSwiftELF.internal_SWIPR_EI_MAG3
let internal_SWIPR_EI_CLASS      = CProfileRecorderSwiftELF.internal_SWIPR_EI_CLASS
let internal_SWIPR_EI_DATA       = CProfileRecorderSwiftELF.internal_SWIPR_EI_DATA
let internal_SWIPR_EI_VERSION    = CProfileRecorderSwiftELF.internal_SWIPR_EI_VERSION
let internal_SWIPR_EI_OSABI      = CProfileRecorderSwiftELF.internal_SWIPR_EI_OSABI
let internal_SWIPR_EI_ABIVERSION = CProfileRecorderSwiftELF.internal_SWIPR_EI_ABIVERSION
let internal_SWIPR_EI_PAD        = CProfileRecorderSwiftELF.internal_SWIPR_EI_PAD

let ELFMAG0 = CProfileRecorderSwiftELF.ELFMAG0
let ELFMAG1 = CProfileRecorderSwiftELF.ELFMAG1
let ELFMAG2 = CProfileRecorderSwiftELF.ELFMAG2
let ELFMAG3 = CProfileRecorderSwiftELF.ELFMAG3

typealias SWIPR_Elf_Ehdr_Class = CProfileRecorderSwiftELF.SWIPR_Elf_Ehdr_Class
typealias SWIPR_Elf_Ehdr_Data  = CProfileRecorderSwiftELF.SWIPR_Elf_Ehdr_Data
typealias SWIPR_Elf_Ehdr_OsAbi = CProfileRecorderSwiftELF.SWIPR_Elf_Ehdr_OsAbi

let internal_SWIPR_SHN_UNDEF     = CProfileRecorderSwiftELF.internal_SWIPR_SHN_UNDEF
let internal_SWIPR_SHN_LORESERVE = CProfileRecorderSwiftELF.internal_SWIPR_SHN_LORESERVE
let internal_SWIPR_SHN_LOPROC    = CProfileRecorderSwiftELF.internal_SWIPR_SHN_LOPROC
let internal_SWIPR_SHN_HIPROC    = CProfileRecorderSwiftELF.internal_SWIPR_SHN_HIPROC
let internal_SWIPR_SHN_LOOS      = CProfileRecorderSwiftELF.internal_SWIPR_SHN_LOOS
let internal_SWIPR_SHN_HIOS      = CProfileRecorderSwiftELF.internal_SWIPR_SHN_HIOS
let internal_SWIPR_SHN_ABS       = CProfileRecorderSwiftELF.internal_SWIPR_SHN_ABS
let internal_SWIPR_SHN_COMMON    = CProfileRecorderSwiftELF.internal_SWIPR_SHN_COMMON
let internal_SWIPR_SHN_XINDEX    = CProfileRecorderSwiftELF.internal_SWIPR_SHN_XINDEX
let internal_SWIPR_SHN_HIRESERVE = CProfileRecorderSwiftELF.internal_SWIPR_SHN_HIRESERVE

typealias SWIPR_Elf_Shdr_Type = CProfileRecorderSwiftELF.SWIPR_Elf_Shdr_Type

let internal_SWIPR_SHF_WRITE            = CProfileRecorderSwiftELF.internal_SWIPR_SHF_WRITE
let internal_SWIPR_SHF_ALLOC            = CProfileRecorderSwiftELF.internal_SWIPR_SHF_ALLOC
let internal_SWIPR_SHF_EXECINSTR        = CProfileRecorderSwiftELF.internal_SWIPR_SHF_EXECINSTR
let internal_SWIPR_SHF_MERGE            = CProfileRecorderSwiftELF.internal_SWIPR_SHF_MERGE
let internal_SWIPR_SHF_STRINGS          = CProfileRecorderSwiftELF.internal_SWIPR_SHF_STRINGS
let internal_SWIPR_SHF_INFO_LINK        = CProfileRecorderSwiftELF.internal_SWIPR_SHF_INFO_LINK
let internal_SWIPR_SHF_LINK_ORDER       = CProfileRecorderSwiftELF.internal_SWIPR_SHF_LINK_ORDER
let internal_SWIPR_SHF_OS_NONCONFORMING = CProfileRecorderSwiftELF.internal_SWIPR_SHF_OS_NONCONFORMING
let internal_SWIPR_SHF_GROUP            = CProfileRecorderSwiftELF.internal_SWIPR_SHF_GROUP
let internal_SWIPR_SHF_TLS              = CProfileRecorderSwiftELF.internal_SWIPR_SHF_TLS
let internal_SWIPR_SHF_COMPRESSED       = CProfileRecorderSwiftELF.internal_SWIPR_SHF_COMPRESSED
let internal_SWIPR_SHF_MASKOS           = CProfileRecorderSwiftELF.internal_SWIPR_SHF_MASKOS
let internal_SWIPR_SHF_MASKPROC         = CProfileRecorderSwiftELF.internal_SWIPR_SHF_MASKPROC

let internal_SWIPR_GRP_COMDAT   = CProfileRecorderSwiftELF.internal_SWIPR_GRP_COMDAT
let internal_SWIPR_GRP_MASKOS   = CProfileRecorderSwiftELF.internal_SWIPR_GRP_MASKOS
let internal_SWIPR_GRP_MASKPROC = CProfileRecorderSwiftELF.internal_SWIPR_GRP_MASKPROC

typealias SWIPR_Elf_Chdr_Type = CProfileRecorderSwiftELF.SWIPR_Elf_Chdr_Type

typealias SWIPR_Elf_Sym_Binding    = CProfileRecorderSwiftELF.SWIPR_Elf_Sym_Binding
typealias SWIPR_Elf_Sym_Type       = CProfileRecorderSwiftELF.SWIPR_Elf_Sym_Type
typealias SWIPR_Elf_Sym_Visibility = CProfileRecorderSwiftELF.SWIPR_Elf_Sym_Visibility

typealias SWIPR_Elf_Phdr_Type  = CProfileRecorderSwiftELF.SWIPR_Elf_Phdr_Type
typealias SWIPR_Elf_Phdr_Flags = CProfileRecorderSwiftELF.SWIPR_Elf_Phdr_Flags

let internal_SWIPR_PF_X = CProfileRecorderSwiftELF.internal_SWIPR_PF_X
let internal_SWIPR_PF_W = CProfileRecorderSwiftELF.internal_SWIPR_PF_W
let internal_SWIPR_PF_R = CProfileRecorderSwiftELF.internal_SWIPR_PF_R

let internal_SWIPR_PF_MASKOS   = CProfileRecorderSwiftELF.internal_SWIPR_PF_MASKOS
let internal_SWIPR_PF_MASKPROC = CProfileRecorderSwiftELF.internal_SWIPR_PF_MASKPROC

let internal_SWIPR_DT_NULL            = CProfileRecorderSwiftELF.internal_SWIPR_DT_NULL
let internal_SWIPR_DT_NEEDED          = CProfileRecorderSwiftELF.internal_SWIPR_DT_NEEDED
let internal_SWIPR_DT_PLTRELSZ        = CProfileRecorderSwiftELF.internal_SWIPR_DT_PLTRELSZ
let internal_SWIPR_DT_PLTGOT          = CProfileRecorderSwiftELF.internal_SWIPR_DT_PLTGOT
let internal_SWIPR_DT_HASH            = CProfileRecorderSwiftELF.internal_SWIPR_DT_HASH
let internal_SWIPR_DT_STRTAB          = CProfileRecorderSwiftELF.internal_SWIPR_DT_STRTAB
let internal_SWIPR_DT_SYMTAB          = CProfileRecorderSwiftELF.internal_SWIPR_DT_SYMTAB
let internal_SWIPR_DT_RELA            = CProfileRecorderSwiftELF.internal_SWIPR_DT_RELA
let internal_SWIPR_DT_RELASZ          = CProfileRecorderSwiftELF.internal_SWIPR_DT_RELASZ
let internal_SWIPR_DT_RELAENT         = CProfileRecorderSwiftELF.internal_SWIPR_DT_RELAENT
let internal_SWIPR_DT_STRSZ           = CProfileRecorderSwiftELF.internal_SWIPR_DT_STRSZ
let internal_SWIPR_DT_SYMENT          = CProfileRecorderSwiftELF.internal_SWIPR_DT_SYMENT
let internal_SWIPR_DT_INIT            = CProfileRecorderSwiftELF.internal_SWIPR_DT_INIT
let internal_SWIPR_DT_FINI            = CProfileRecorderSwiftELF.internal_SWIPR_DT_FINI
let internal_SWIPR_DT_SONAME          = CProfileRecorderSwiftELF.internal_SWIPR_DT_SONAME
let internal_SWIPR_DT_RPATH           = CProfileRecorderSwiftELF.internal_SWIPR_DT_RPATH
let internal_SWIPR_DT_SYMBOLIC        = CProfileRecorderSwiftELF.internal_SWIPR_DT_SYMBOLIC
let internal_SWIPR_DT_REL             = CProfileRecorderSwiftELF.internal_SWIPR_DT_REL
let internal_SWIPR_DT_RELSZ           = CProfileRecorderSwiftELF.internal_SWIPR_DT_RELSZ
let internal_SWIPR_DT_RELENT          = CProfileRecorderSwiftELF.internal_SWIPR_DT_RELENT
let internal_SWIPR_DT_PLTREL          = CProfileRecorderSwiftELF.internal_SWIPR_DT_PLTREL
let internal_SWIPR_DT_DEBUG           = CProfileRecorderSwiftELF.internal_SWIPR_DT_DEBUG
let internal_SWIPR_DT_TEXTREL         = CProfileRecorderSwiftELF.internal_SWIPR_DT_TEXTREL
let internal_SWIPR_DT_JMPREL          = CProfileRecorderSwiftELF.internal_SWIPR_DT_JMPREL
let internal_SWIPR_DT_BIND_NOW        = CProfileRecorderSwiftELF.internal_SWIPR_DT_BIND_NOW
let internal_SWIPR_DT_INIT_ARRAY      = CProfileRecorderSwiftELF.internal_SWIPR_DT_INIT_ARRAY
let internal_SWIPR_DT_FINI_ARRAY      = CProfileRecorderSwiftELF.internal_SWIPR_DT_FINI_ARRAY
let internal_SWIPR_DT_INIT_ARRAYSZ    = CProfileRecorderSwiftELF.internal_SWIPR_DT_INIT_ARRAYSZ
let internal_SWIPR_DT_FINI_ARRAYSZ    = CProfileRecorderSwiftELF.internal_SWIPR_DT_FINI_ARRAYSZ
let internal_SWIPR_DT_RUNPATH         = CProfileRecorderSwiftELF.internal_SWIPR_DT_RUNPATH
let internal_SWIPR_DT_FLAGS           = CProfileRecorderSwiftELF.internal_SWIPR_DT_FLAGS
let internal_SWIPR_DT_ENCODING        = CProfileRecorderSwiftELF.internal_SWIPR_DT_ENCODING
let internal_SWIPR_DT_PREINIT_ARRAY   = CProfileRecorderSwiftELF.internal_SWIPR_DT_PREINIT_ARRAY
let internal_SWIPR_DT_PREINIT_ARRAYSZ = CProfileRecorderSwiftELF.internal_SWIPR_DT_PREINIT_ARRAYSZ
let internal_SWIPR_DT_LOOS            = CProfileRecorderSwiftELF.internal_SWIPR_DT_LOOS
let internal_SWIPR_DT_HIOS            = CProfileRecorderSwiftELF.internal_SWIPR_DT_HIOS
let internal_SWIPR_DT_LOPROC          = CProfileRecorderSwiftELF.internal_SWIPR_DT_LOPROC
let internal_SWIPR_DT_HIPROC          = CProfileRecorderSwiftELF.internal_SWIPR_DT_HIPROC

let internal_SWIPR_DF_ORIGIN     = CProfileRecorderSwiftELF.internal_SWIPR_DF_ORIGIN
let internal_SWIPR_DF_SYMBOLIC   = CProfileRecorderSwiftELF.internal_SWIPR_DF_SYMBOLIC
let internal_SWIPR_DF_TEXTREL    = CProfileRecorderSwiftELF.internal_SWIPR_DF_TEXTREL
let internal_SWIPR_DF_BIND_NOW   = CProfileRecorderSwiftELF.internal_SWIPR_DF_BIND_NOW
let internal_SWIPR_DF_STATIC_TLS = CProfileRecorderSwiftELF.internal_SWIPR_DF_STATIC_TLS

let internal_SWIPR_NT_GNU_ABI_TAG         = CProfileRecorderSwiftELF.internal_SWIPR_NT_GNU_ABI_TAG
let internal_SWIPR_NT_GNU_HWCAP           = CProfileRecorderSwiftELF.internal_SWIPR_NT_GNU_HWCAP
let internal_SWIPR_NT_GNU_BUILD_ID        = CProfileRecorderSwiftELF.internal_SWIPR_NT_GNU_BUILD_ID
let internal_SWIPR_NT_GNU_GOLD_VERSION    = CProfileRecorderSwiftELF.internal_SWIPR_NT_GNU_GOLD_VERSION
let internal_SWIPR_NT_GNU_PROPERTY_TYPE_0 = CProfileRecorderSwiftELF.internal_SWIPR_NT_GNU_PROPERTY_TYPE_0

typealias SWIPR_Elf32_Ehdr = CProfileRecorderSwiftELF.SWIPR_Elf32_Ehdr
typealias SWIPR_Elf64_Ehdr = CProfileRecorderSwiftELF.SWIPR_Elf64_Ehdr

typealias SWIPR_Elf32_Shdr = CProfileRecorderSwiftELF.SWIPR_Elf32_Shdr
typealias SWIPR_Elf64_Shdr = CProfileRecorderSwiftELF.SWIPR_Elf64_Shdr

typealias SWIPR_Elf32_Chdr = CProfileRecorderSwiftELF.SWIPR_Elf32_Chdr
typealias SWIPR_Elf64_Chdr = CProfileRecorderSwiftELF.SWIPR_Elf64_Chdr

typealias SWIPR_Elf32_Sym = CProfileRecorderSwiftELF.SWIPR_Elf32_Sym
typealias SWIPR_Elf64_Sym = CProfileRecorderSwiftELF.SWIPR_Elf64_Sym

nonisolated(unsafe) let ELF32_ST_BIND       = CProfileRecorderSwiftELF.ELF32_ST_BIND
nonisolated(unsafe) let ELF32_ST_TYPE       = CProfileRecorderSwiftELF.ELF32_ST_TYPE
nonisolated(unsafe) let ELF32_ST_INFO       = CProfileRecorderSwiftELF.ELF32_ST_INFO
nonisolated(unsafe) let ELF32_ST_VISIBILITY = CProfileRecorderSwiftELF.ELF32_ST_VISIBILITY

nonisolated(unsafe) let ELF64_ST_BIND       = CProfileRecorderSwiftELF.ELF64_ST_BIND
nonisolated(unsafe) let ELF64_ST_TYPE       = CProfileRecorderSwiftELF.ELF64_ST_TYPE
nonisolated(unsafe) let ELF64_ST_INFO       = CProfileRecorderSwiftELF.ELF64_ST_INFO
nonisolated(unsafe) let ELF64_ST_VISIBILITY = CProfileRecorderSwiftELF.ELF64_ST_VISIBILITY

typealias SWIPR_Elf32_Rel  = CProfileRecorderSwiftELF.SWIPR_Elf32_Rel
typealias SWIPR_Elf32_Rela = CProfileRecorderSwiftELF.SWIPR_Elf32_Rela
typealias SWIPR_Elf64_Rel  = CProfileRecorderSwiftELF.SWIPR_Elf64_Rel
typealias SWIPR_Elf64_Rela = CProfileRecorderSwiftELF.SWIPR_Elf64_Rela

nonisolated(unsafe) let ELF32_R_SYM  = CProfileRecorderSwiftELF.ELF32_R_SYM
nonisolated(unsafe) let ELF32_R_TYPE = CProfileRecorderSwiftELF.ELF32_R_TYPE
nonisolated(unsafe) let ELF32_R_INFO = CProfileRecorderSwiftELF.ELF32_R_INFO

nonisolated(unsafe) let ELF64_R_SYM  = CProfileRecorderSwiftELF.ELF64_R_SYM
nonisolated(unsafe) let ELF64_R_TYPE = CProfileRecorderSwiftELF.ELF64_R_TYPE
nonisolated(unsafe) let ELF64_R_INFO = CProfileRecorderSwiftELF.ELF64_R_INFO

typealias SWIPR_Elf32_Phdr = CProfileRecorderSwiftELF.SWIPR_Elf32_Phdr
typealias SWIPR_Elf64_Phdr = CProfileRecorderSwiftELF.SWIPR_Elf64_Phdr

typealias SWIPR_Elf32_Nhdr = CProfileRecorderSwiftELF.SWIPR_Elf32_Nhdr
typealias SWIPR_Elf64_Nhdr = CProfileRecorderSwiftELF.SWIPR_Elf64_Nhdr

typealias SWIPR_Elf32_Dyn = CProfileRecorderSwiftELF.SWIPR_Elf32_Dyn
typealias SWIPR_Elf64_Dyn = CProfileRecorderSwiftELF.SWIPR_Elf64_Dyn

typealias SWIPR_Elf32_Hash = CProfileRecorderSwiftELF.SWIPR_Elf32_Hash
typealias SWIPR_Elf64_Hash = CProfileRecorderSwiftELF.SWIPR_Elf64_Hash

nonisolated(unsafe) let SWIPR_elf_hash = CProfileRecorderSwiftELF.SWIPR_elf_hash

// .. Utilities ................................................................

private func realPath(_ path: String) -> String? {
  guard let result = realpath(path, nil) else {
    return nil
  }

  let s = String(cString: result)

  free(result)

  return s
}

private func dirname(_ path: String) -> Substring {
  guard let lastSlash = path.lastIndex(of: "/") else {
    return ""
  }
  return path.prefix(upTo: lastSlash)
}

private let crc32Table: [UInt32] = [
  0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f,
  0xe963a535, 0x9e6495a3, 0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
  0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91, 0x1db71064, 0x6ab020f2,
  0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
  0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9,
  0xfa0f3d63, 0x8d080df5, 0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
  0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b, 0x35b5a8fa, 0x42b2986c,
  0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
  0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423,
  0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
  0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d, 0x76dc4190, 0x01db7106,
  0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
  0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d,
  0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
  0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950,
  0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
  0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7,
  0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
  0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa,
  0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
  0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81,
  0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
  0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683, 0xe3630b12, 0x94643b84,
  0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
  0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb,
  0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
  0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5, 0xd6d6a3e8, 0xa1d1937e,
  0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
  0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55,
  0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
  0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe, 0xb2bd0b28,
  0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
  0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f,
  0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
  0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242,
  0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
  0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69,
  0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
  0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc,
  0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
  0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693,
  0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
  0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d
]

private func updateCrc(_ crc: UInt32,
                       _ bytes: UnsafeRawBufferPointer) -> UInt32 {
  var theCrc = ~crc
  for byte in bytes {
    theCrc = crc32Table[Int(UInt8(truncatingIfNeeded: theCrc)
                              ^ byte)] ^ (theCrc >> 8)
  }
  return ~theCrc
}

// .. Byte swapping ............................................................

extension SWIPR_Elf32_Ehdr: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf32_Ehdr(
      e_ident: e_ident,
      e_type: SWIPR_Elf_Ehdr_Type(rawValue: e_type.rawValue.byteSwapped)!,
      e_machine: SWIPR_Elf_Ehdr_Machine(rawValue: e_machine.rawValue.byteSwapped)!,
      e_version: SWIPR_Elf_Ehdr_Version(rawValue: e_version.rawValue.byteSwapped)!,
      e_entry: e_entry.byteSwapped,
      e_phoff: e_phoff.byteSwapped,
      e_shoff: e_shoff.byteSwapped,
      e_flags: e_flags.byteSwapped,
      e_ehsize: e_ehsize.byteSwapped,
      e_phentsize: e_phentsize.byteSwapped,
      e_phnum: e_phnum.byteSwapped,
      e_shentsize: e_shentsize.byteSwapped,
      e_shnum: e_shnum.byteSwapped,
      e_shstrndx: e_shstrndx.byteSwapped
    )
  }
}

extension SWIPR_Elf64_Ehdr: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf64_Ehdr(
      e_ident: e_ident,
      e_type: SWIPR_Elf_Ehdr_Type(rawValue: e_type.rawValue.byteSwapped)!,
      e_machine: SWIPR_Elf_Ehdr_Machine(rawValue: e_machine.rawValue.byteSwapped)!,
      e_version: SWIPR_Elf_Ehdr_Version(rawValue: e_version.rawValue.byteSwapped)!,
      e_entry: e_entry.byteSwapped,
      e_phoff: e_phoff.byteSwapped,
      e_shoff: e_shoff.byteSwapped,
      e_flags: e_flags.byteSwapped,
      e_ehsize: e_ehsize.byteSwapped,
      e_phentsize: e_phentsize.byteSwapped,
      e_phnum: e_phnum.byteSwapped,
      e_shentsize: e_shentsize.byteSwapped,
      e_shnum: e_shnum.byteSwapped,
      e_shstrndx: e_shstrndx.byteSwapped
    )
  }
}

extension SWIPR_Elf32_Shdr: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf32_Shdr(
      sh_name: sh_name.byteSwapped,
      sh_type: SWIPR_Elf_Shdr_Type(rawValue: sh_type.rawValue.byteSwapped)!,
      sh_flags: sh_flags.byteSwapped,
      sh_addr: sh_addr.byteSwapped,
      sh_offset: sh_offset.byteSwapped,
      sh_size: sh_size.byteSwapped,
      sh_link: sh_link.byteSwapped,
      sh_info: sh_info.byteSwapped,
      sh_addralign: sh_addralign.byteSwapped,
      sh_entsize: sh_entsize.byteSwapped
    )
  }
}

extension SWIPR_Elf64_Shdr: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf64_Shdr(
      sh_name: sh_name.byteSwapped,
      sh_type: SWIPR_Elf_Shdr_Type(rawValue: sh_type.rawValue.byteSwapped)!,
      sh_flags: sh_flags.byteSwapped,
      sh_addr: sh_addr.byteSwapped,
      sh_offset: sh_offset.byteSwapped,
      sh_size: sh_size.byteSwapped,
      sh_link: sh_link.byteSwapped,
      sh_info: sh_info.byteSwapped,
      sh_addralign: sh_addralign.byteSwapped,
      sh_entsize: sh_entsize.byteSwapped
    )
  }
}

protocol SWIPR_Elf_Chdr: ByteSwappable {
  associatedtype Size: FixedWidthInteger

  init()

  var ch_type: SWIPR_Elf_Chdr_Type { get set }
  var ch_size: Size { get set }
  var ch_addralign: Size { get set }
}

extension SWIPR_Elf32_Chdr: SWIPR_Elf_Chdr {
  var byteSwapped: Self {
    return SWIPR_Elf32_Chdr(
      ch_type: SWIPR_Elf_Chdr_Type(rawValue: ch_type.rawValue.byteSwapped)!,
      ch_size: ch_size.byteSwapped,
      ch_addralign: ch_addralign.byteSwapped
    )
  }
}

extension SWIPR_Elf64_Chdr: SWIPR_Elf_Chdr {
  var byteSwapped: Self {
    return SWIPR_Elf64_Chdr(
      ch_type: SWIPR_Elf_Chdr_Type(rawValue: ch_type.rawValue.byteSwapped)!,
      ch_reserved: ch_reserved.byteSwapped,
      ch_size: ch_size.byteSwapped,
      ch_addralign: ch_addralign.byteSwapped
    )
  }
}

extension SWIPR_Elf_Chdr_Type: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf_Chdr_Type(rawValue: rawValue.byteSwapped)!
  }
}

extension SWIPR_Elf32_Sym: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf32_Sym(
      st_name: st_name.byteSwapped,
      st_value: st_value.byteSwapped,
      st_size: st_size.byteSwapped,
      st_info: st_info.byteSwapped,
      st_other: st_other.byteSwapped,
      st_shndx: st_shndx.byteSwapped
    )
  }
}

extension SWIPR_Elf64_Sym: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf64_Sym(
      st_name: st_name.byteSwapped,
      st_info: st_info.byteSwapped,
      st_other: st_other.byteSwapped,
      st_shndx: st_shndx.byteSwapped,
      st_value: st_value.byteSwapped,
      st_size: st_size.byteSwapped
    )
  }
}

extension SWIPR_Elf32_Rel: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf32_Rel(
      r_offset: r_offset.byteSwapped,
      r_info: r_info.byteSwapped
    )
  }
}

extension SWIPR_Elf32_Rela: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf32_Rela(
      r_offset: r_offset.byteSwapped,
      r_info: r_info.byteSwapped,
      r_addend: r_addend.byteSwapped
    )
  }
}

extension SWIPR_Elf64_Rel: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf64_Rel(
      r_offset: r_offset.byteSwapped,
      r_info: r_info.byteSwapped
    )
  }
}

extension SWIPR_Elf64_Rela: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf64_Rela(
      r_offset: r_offset.byteSwapped,
      r_info: r_info.byteSwapped,
      r_addend: r_addend.byteSwapped
    )
  }
}

extension SWIPR_Elf32_Phdr: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf32_Phdr(
      p_type: SWIPR_Elf_Phdr_Type(rawValue: p_type.rawValue.byteSwapped)!,
      p_offset: p_offset.byteSwapped,
      p_vaddr: p_vaddr.byteSwapped,
      p_paddr: p_paddr.byteSwapped,
      p_filesz: p_filesz.byteSwapped,
      p_memsz: p_memsz.byteSwapped,
      p_flags: p_flags.byteSwapped,
      p_align: p_align.byteSwapped
    )
  }
}

extension SWIPR_Elf64_Phdr: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf64_Phdr(
      p_type: SWIPR_Elf_Phdr_Type(rawValue: p_type.rawValue.byteSwapped)!,
      p_flags: p_flags.byteSwapped,
      p_offset: p_offset.byteSwapped,
      p_vaddr: p_vaddr.byteSwapped,
      p_paddr: p_paddr.byteSwapped,
      p_filesz: p_filesz.byteSwapped,
      p_memsz: p_memsz.byteSwapped,
      p_align: p_align.byteSwapped
    )
  }
}

extension SWIPR_Elf32_Nhdr: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf32_Nhdr(
      n_namesz: n_namesz.byteSwapped,
      n_descsz: n_descsz.byteSwapped,
      n_type: n_type.byteSwapped
    )
  }
}

extension SWIPR_Elf64_Nhdr: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf64_Nhdr(
      n_namesz: n_namesz.byteSwapped,
      n_descsz: n_descsz.byteSwapped,
      n_type: n_type.byteSwapped
    )
  }
}

extension SWIPR_Elf32_Dyn: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf32_Dyn(
      d_tag: d_tag.byteSwapped,
      d_un: .init(d_val: d_un.d_val.byteSwapped)
    )
  }
}

extension SWIPR_Elf64_Dyn: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf64_Dyn(
      d_tag: d_tag.byteSwapped,
      d_un: .init(d_val: d_un.d_val.byteSwapped)
    )
  }
}

extension SWIPR_Elf32_Hash: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf32_Hash(
      h_nbucket: h_nbucket.byteSwapped,
      h_nchain: h_nchain.byteSwapped
    )
  }
}

extension SWIPR_Elf64_Hash: ByteSwappable {
  var byteSwapped: Self {
    return SWIPR_Elf64_Hash(
      h_nbucket: h_nbucket.byteSwapped,
      h_nchain: h_nchain.byteSwapped
    )
  }
}

// .. Protocols ................................................................

typealias SWIPR_Elf_Magic = (UInt8, UInt8, UInt8, UInt8)

typealias SWIPR_Elf_Ident = (
  UInt8, UInt8, UInt8, UInt8,
  UInt8, UInt8, UInt8, UInt8,
  UInt8, UInt8, UInt8, UInt8,
  UInt8, UInt8, UInt8, UInt8
)

let ElfMagic: SWIPR_Elf_Magic = (0x7f, 0x45, 0x4c, 0x46)

protocol SWIPR_Elf_Ehdr : ByteSwappable {
  associatedtype Address: FixedWidthInteger
  associatedtype Offset: FixedWidthInteger

  init()

  var e_ident: SWIPR_Elf_Ident { get set }
  var ei_magic: SWIPR_Elf_Magic { get set }
  var ei_class: SWIPR_Elf_Ehdr_Class { get set }
  var ei_data: SWIPR_Elf_Ehdr_Data { get set }
  var ei_version: SWIPR_Elf_Byte { get set }
  var ei_osabi: SWIPR_Elf_Ehdr_OsAbi { get set }
  var ei_abiversion: SWIPR_Elf_Byte { get set }

  var e_type: SWIPR_Elf_Ehdr_Type { get set }
  var e_machine: SWIPR_Elf_Ehdr_Machine { get set }
  var e_version: SWIPR_Elf_Ehdr_Version { get set }
  var e_entry: Address { get set }
  var e_phoff: Offset { get set }
  var e_shoff: Offset { get set }
  var e_flags: SWIPR_Elf_Word { get set }
  var e_ehsize: SWIPR_Elf_Half { get set }
  var e_phentsize: SWIPR_Elf_Half { get set }
  var e_phnum: SWIPR_Elf_Half { get set }
  var e_shentsize: SWIPR_Elf_Half { get set }
  var e_shnum: SWIPR_Elf_Half { get set }
  var e_shstrndx: SWIPR_Elf_Half { get set }

  var shouldByteSwap: Bool { get }
}

extension SWIPR_Elf_Ehdr {
  var ei_magic: SWIPR_Elf_Magic {
    get {
      return (e_ident.0, e_ident.1, e_ident.2, e_ident.3)
    }
    set {
      e_ident.0 = newValue.0
      e_ident.1 = newValue.1
      e_ident.2 = newValue.2
      e_ident.3 = newValue.3
    }
  }
  var ei_class: SWIPR_Elf_Ehdr_Class {
    get {
      return SWIPR_Elf_Ehdr_Class(rawValue: e_ident.4)!
    }
    set {
      e_ident.4 = newValue.rawValue
    }
  }
  var ei_data: SWIPR_Elf_Ehdr_Data {
    get {
      return SWIPR_Elf_Ehdr_Data(rawValue: e_ident.5)!
    }
    set {
      e_ident.5 = newValue.rawValue
    }
  }
  var ei_version: UInt8 {
    get {
      return e_ident.6
    }
    set {
      e_ident.6 = newValue
    }
  }
  var ei_osabi: SWIPR_Elf_Ehdr_OsAbi {
    get {
      return SWIPR_Elf_Ehdr_OsAbi(rawValue: e_ident.7)!
    }
    set {
      e_ident.7 = newValue.rawValue
    }
  }
  var ei_abiversion: UInt8 {
    get {
      return e_ident.8
    }
    set {
      e_ident.8 = newValue
    }
  }
  var ei_pad: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) {
    get {
      return (e_ident.9, e_ident.10, e_ident.11,
              e_ident.12, e_ident.13, e_ident.14,
              e_ident.15)
    }
    set {
      e_ident.9 = newValue.0
      e_ident.10 = newValue.1
      e_ident.11 = newValue.2
      e_ident.12 = newValue.3
      e_ident.13 = newValue.4
      e_ident.14 = newValue.5
      e_ident.15 = newValue.6
    }
  }

  var shouldByteSwap: Bool {
    #if _endian(big)
    return ei_data == .ELFDATA2LSB
    #else
    return ei_data == .ELFDATA2MSB
    #endif
  }
}

extension SWIPR_Elf32_Ehdr : SWIPR_Elf_Ehdr {
}

extension SWIPR_Elf64_Ehdr : SWIPR_Elf_Ehdr {
}

protocol SWIPR_Elf_Shdr : ByteSwappable {
  associatedtype Flags: FixedWidthInteger
  associatedtype Address: FixedWidthInteger
  associatedtype Offset: FixedWidthInteger
  associatedtype Size: FixedWidthInteger

  init()

  var sh_name: SWIPR_Elf_Word { get set }
  var sh_type: SWIPR_Elf_Shdr_Type { get set }
  var sh_flags: Flags { get set }
  var sh_addr: Address { get set }
  var sh_offset: Offset { get set }
  var sh_size: Size { get set }
  var sh_link: SWIPR_Elf_Word { get set }
  var sh_info: SWIPR_Elf_Word { get set }
  var sh_addralign: Size { get set }
  var sh_entsize: Size { get set }
}

extension SWIPR_Elf32_Shdr : SWIPR_Elf_Shdr {
}

extension SWIPR_Elf64_Shdr : SWIPR_Elf_Shdr {
}

protocol SWIPR_Elf_Phdr : ByteSwappable {
  associatedtype Address: FixedWidthInteger
  associatedtype Offset: FixedWidthInteger
  associatedtype Size: FixedWidthInteger

  init()

  var p_type: SWIPR_Elf_Phdr_Type { get set }
  var p_flags: SWIPR_Elf_Phdr_Flags { get set }
  var p_offset: Offset { get set }
  var p_vaddr: Address { get set }
  var p_paddr: Address { get set }
  var p_filesz: Size { get set }
  var p_memsz: Size { get set }
  var p_align: Size { get set }
}

extension SWIPR_Elf32_Phdr : SWIPR_Elf_Phdr {
}

extension SWIPR_Elf64_Phdr : SWIPR_Elf_Phdr {
}

protocol SWIPR_Elf_Nhdr : ByteSwappable {
  init()

  var n_namesz: SWIPR_Elf_Word { get set }
  var n_descsz: SWIPR_Elf_Word { get set }
  var n_type: SWIPR_Elf_Word { get set }
}

extension SWIPR_Elf32_Nhdr : SWIPR_Elf_Nhdr {
}

extension SWIPR_Elf64_Nhdr : SWIPR_Elf_Nhdr {
}

protocol SWIPR_Elf_Sym {
  associatedtype Address: FixedWidthInteger
  associatedtype Size: FixedWidthInteger

  var st_name: SWIPR_Elf_Word { get set }
  var st_value: Address { get set }
  var st_size: Size { get set }
  var st_info: SWIPR_Elf_Byte { get set }
  var st_other: SWIPR_Elf_Byte { get set }
  var st_shndx: SWIPR_Elf_Half { get set }

  var st_binding: SWIPR_Elf_Sym_Binding { get set }
  var st_type: SWIPR_Elf_Sym_Type { get set }
  var st_visibility: SWIPR_Elf_Sym_Visibility { get set }
}

extension SWIPR_Elf32_Sym: SWIPR_Elf_Sym {
  var st_binding: SWIPR_Elf_Sym_Binding {
    get {
      return ELF32_ST_BIND(st_info)
    }
    set {
      st_info = ELF32_ST_INFO(newValue, ELF32_ST_TYPE(st_info))
    }
  }

  var st_type: SWIPR_Elf_Sym_Type {
    get {
      return ELF32_ST_TYPE(st_info)
    }
    set {
      st_info = ELF32_ST_INFO(ELF32_ST_BIND(st_info), newValue)
    }
  }

  var st_visibility: SWIPR_Elf_Sym_Visibility {
    get {
      return ELF32_ST_VISIBILITY(st_other)
    }
    set {
      st_other = (st_other & ~3) | newValue.rawValue
    }
  }
}

extension SWIPR_Elf64_Sym: SWIPR_Elf_Sym {
  var st_binding: SWIPR_Elf_Sym_Binding {
    get {
      return ELF64_ST_BIND(st_info)
    }
    set {
      st_info = ELF64_ST_INFO(newValue, ELF64_ST_TYPE(st_info))
    }
  }

  var st_type: SWIPR_Elf_Sym_Type {
    get {
      return ELF64_ST_TYPE(st_info)
    }
    set {
      st_info = ELF64_ST_INFO(ELF64_ST_BIND(st_info), newValue)
    }
  }

  var st_visibility: SWIPR_Elf_Sym_Visibility {
    get {
      return ELF64_ST_VISIBILITY(st_other)
    }
    set {
      st_other = (st_other & ~3) | newValue.rawValue
    }
  }
}

extension SWIPR_Elf32_Rel {
  var r_sym: SWIPR_Elf32_Byte {
    get {
      return ELF32_R_SYM(r_info)
    }
    set {
      r_info = ELF32_R_INFO(newValue, ELF32_R_TYPE(r_info))
    }
  }

  var r_type: SWIPR_Elf32_Byte {
    get {
      return ELF32_R_TYPE(r_info)
    }
    set {
      r_info = ELF32_R_INFO(ELF32_R_SYM(r_info), newValue)
    }
  }
}

extension SWIPR_Elf32_Rela {
  var r_sym: SWIPR_Elf32_Byte {
    get {
      return ELF32_R_SYM(r_info)
    }
    set {
      r_info = ELF32_R_INFO(newValue, ELF32_R_TYPE(r_info))
    }
  }

  var r_type: SWIPR_Elf32_Byte {
    get {
      return ELF32_R_TYPE(r_info)
    }
    set {
      r_info = ELF32_R_INFO(ELF32_R_SYM(r_info), newValue)
    }
  }
}

extension SWIPR_Elf64_Rel {
  var r_sym: SWIPR_Elf64_Word {
    get {
      return ELF64_R_SYM(r_info)
    }
    set {
      r_info = ELF64_R_INFO(newValue, ELF64_R_TYPE(r_info))
    }
  }

  var r_type: SWIPR_Elf64_Word {
    get {
      return ELF64_R_TYPE(r_info)
    }
    set {
      r_info = ELF64_R_INFO(ELF64_R_SYM(r_info), newValue)
    }
  }
}

extension SWIPR_Elf64_Rela {
  var r_sym: SWIPR_Elf64_Word {
    get {
      return ELF64_R_SYM(r_info)
    }
    set {
      r_info = ELF64_R_INFO(newValue, ELF64_R_TYPE(r_info))
    }
  }

  var r_type: SWIPR_Elf64_Word {
    get {
      return ELF64_R_TYPE(r_info)
    }
    set {
      r_info = ELF64_R_INFO(ELF64_R_SYM(r_info), newValue)
    }
  }
}

// .. Traits ...................................................................

protocol ElfTraits {
  associatedtype Address: FixedWidthInteger
  associatedtype Offset: FixedWidthInteger
  associatedtype Size: FixedWidthInteger

  associatedtype Ehdr: SWIPR_Elf_Ehdr where Ehdr.Address == Address,
                                      Ehdr.Offset == Offset
  associatedtype Phdr: SWIPR_Elf_Phdr where Phdr.Address == Address,
                                      Phdr.Offset == Offset,
                                      Phdr.Size == Size
  associatedtype Shdr: SWIPR_Elf_Shdr where Shdr.Address == Address,
                                      Shdr.Offset == Offset,
                                      Shdr.Size == Size
  associatedtype Nhdr: SWIPR_Elf_Nhdr
  associatedtype Chdr: SWIPR_Elf_Chdr where Chdr.Size == Size
  associatedtype Sym: SWIPR_Elf_Sym where Sym.Address == Address, Sym.Size == Size

  static var elfClass: SWIPR_Elf_Ehdr_Class { get }
}

struct Elf32Traits: ElfTraits {
  typealias Address = UInt32
  typealias Offset = UInt32
  typealias Size = UInt32

  typealias Ehdr = SWIPR_Elf32_Ehdr
  typealias Phdr = SWIPR_Elf32_Phdr
  typealias Shdr = SWIPR_Elf32_Shdr
  typealias Nhdr = SWIPR_Elf32_Nhdr
  typealias Chdr = SWIPR_Elf32_Chdr
  typealias Sym = SWIPR_Elf32_Sym

  static let elfClass: SWIPR_Elf_Ehdr_Class = .ELFCLASS32
}

struct Elf64Traits: ElfTraits {
  typealias Address = UInt64
  typealias Offset = UInt64
  typealias Size = UInt64

  typealias Ehdr = SWIPR_Elf64_Ehdr
  typealias Phdr = SWIPR_Elf64_Phdr
  typealias Shdr = SWIPR_Elf64_Shdr
  typealias Nhdr = SWIPR_Elf64_Nhdr
  typealias Chdr = SWIPR_Elf64_Chdr
  typealias Sym = SWIPR_Elf64_Sym

  static let elfClass: SWIPR_Elf_Ehdr_Class = .ELFCLASS64
}

// .. ElfStringSection .........................................................

struct ElfStringSection {
  let source: ImageSource

  func getStringAt(index: Int) -> String? {
    if index < 0 || index >= source.bytes.count {
      return nil
    }

    let slice = UnsafeRawBufferPointer(rebasing: source.bytes[index...])
    var len: Int = 0
    len = strnlen(slice.baseAddress!, slice.count)
    return String(decoding: source.bytes[index..<index+len], as: UTF8.self)
  }
}

// .. ElfImage .................................................................

enum ElfImageError: Error {
  case notAnElfImage
  case wrongClass
  case badNoteName
  case badStringTableSectionIndex
}

protocol ElfSymbolProtocol: Equatable {
  associatedtype Address: FixedWidthInteger
  associatedtype Size: FixedWidthInteger

  var name: String { get set }
  var value: Address { get set }
  var size: Size { get set }
  var sectionIndex: Int { get set }
  var binding: SWIPR_Elf_Sym_Binding { get set }
  var type: SWIPR_Elf_Sym_Type { get set }
  var visibility: SWIPR_Elf_Sym_Visibility { get set }
}

protocol ElfSymbolTableProtocol {
  associatedtype Traits: ElfTraits
  associatedtype Symbol: ElfSymbolProtocol where Symbol.Address == Traits.Address,
                                                 Symbol.Size == Traits.Size

  func lookupSymbol(address: Traits.Address) -> Symbol?
}

protocol ElfSymbolLookupProtocol {
  associatedtype Traits: ElfTraits
  typealias CallSiteInfo = DwarfReader<ElfImage<Traits>>.CallSiteInfo
  

  func lookupSymbol(address: Traits.Address) -> ImageSymbol?
  func inlineCallSites(at address: Traits.Address) -> ArraySlice<CallSiteInfo>
  func sourceLocation(for address: Traits.Address) throws -> SourceLocation?
}

struct ElfSymbolTable<SomeElfTraits: ElfTraits>: ElfSymbolTableProtocol {
  typealias Traits = SomeElfTraits

  struct Symbol: ElfSymbolProtocol {
    typealias Address = Traits.Address
    typealias Size = Traits.Size

    var name: String
    var value: Address
    var size: Size
    var sectionIndex: Int
    var binding: SWIPR_Elf_Sym_Binding
    var type: SWIPR_Elf_Sym_Type
    var visibility: SWIPR_Elf_Sym_Visibility
  }

  private var _symbols: [Symbol] = []

  init() {}

  @_specialize(kind: full, where SomeElfTraits == Elf32Traits)
  @_specialize(kind: full, where SomeElfTraits == Elf64Traits)
  init?(image: ElfImage<Traits>) {
    guard let strtab = image.getSection(".strtab", debug: false),
          let symtab = image.getSection(".symtab", debug: false) else {
      return nil
    }

    let stringSect = ElfStringSection(source: strtab)

    // Extract all the data
    symtab.bytes.withMemoryRebound(to: Traits.Sym.self) { symbols in
      for symbol in symbols {
        // Ignore things that are not functions
        if symbol.st_type != .internal_SWIPR_STT_FUNC {
          continue
        }

        // Ignore anything undefined
        if symbol.st_shndx == internal_SWIPR_SHN_UNDEF {
          continue
        }

        _symbols.append(
          Symbol(
            name: (stringSect.getStringAt(index: Int(symbol.st_name))
                     ?? "<unknown>"),
            value: symbol.st_value,
            size: symbol.st_size,
            sectionIndex: Int(symbol.st_shndx),
            binding: symbol.st_binding,
            type: symbol.st_type,
            visibility: symbol.st_visibility
          )
        )
      }
    }

    // Now sort by address
    _symbols.sort(by: {
                    $0.value < $1.value || (
                      $0.value == $1.value && $0.size < $1.size
                    )
                  })
  }

  private init(sortedSymbols: [Symbol]) {
    _symbols = sortedSymbols
  }

  @_specialize(kind: full, where SomeElfTraits == Elf32Traits)
  @_specialize(kind: full, where SomeElfTraits == Elf64Traits)
  public func merged(with other: ElfSymbolTable<Traits>) -> ElfSymbolTable<Traits> {
    var merged: [Symbol] = []

    var ourNdx = 0, theirNdx = 0

    while ourNdx < _symbols.count && theirNdx < other._symbols.count {
        let ourSym = _symbols[ourNdx]
        let theirSym = other._symbols[theirNdx]

        if ourSym.value < theirSym.value {
          merged.append(ourSym)
          ourNdx += 1
        } else if ourSym.value > theirSym.value {
          merged.append(theirSym)
          theirNdx += 1
        } else if ourSym == theirSym {
          merged.append(ourSym)
          ourNdx += 1
          theirNdx += 1
        } else {
          if ourSym.size <= theirSym.size {
            merged.append(ourSym)
          }
          merged.append(theirSym)
          if ourSym.size > theirSym.size {
            merged.append(theirSym)
          }
          ourNdx += 1
          theirNdx += 1
        }
      }

      if ourNdx < _symbols.count {
        merged.append(contentsOf:_symbols[ourNdx...])
      }
      if theirNdx < other._symbols.count {
        merged.append(contentsOf:other._symbols[theirNdx...])
      }

      return ElfSymbolTable(sortedSymbols: merged)
  }

  @_specialize(kind: full, where SomeElfTraits == Elf32Traits)
  @_specialize(kind: full, where SomeElfTraits == Elf64Traits)
  public func lookupSymbol(address: Traits.Address) -> Symbol? {
    var min = 0
    var max = _symbols.count

    while min < max {
      let mid = min + (max - min) / 2
      let symbol = _symbols[mid]
      let nextValue: Traits.Address
      if mid == _symbols.count - 1 {
        nextValue = ~Traits.Address(0)
      } else {
        nextValue = _symbols[mid + 1].value
      }

      if symbol.value <= address && nextValue > address {
        var ndx = mid
        while ndx > 0 && _symbols[ndx - 1].value == address {
          ndx -= 1
        }
        return _symbols[ndx]
      } else if symbol.value <= address {
        min = mid + 1
      } else if symbol.value > address {
        max = mid
      }
    }

    return nil
  }
}

final class ElfImage<SomeElfTraits: ElfTraits>
  : DwarfSource, ElfSymbolLookupProtocol {
  typealias Traits = SomeElfTraits
  typealias SymbolTable = ElfSymbolTable<SomeElfTraits>

  // This is arbitrary and it isn't in the spec
  let maxNoteNameLength = 256

  var baseAddress: ImageSource.Address
  var endAddress: ImageSource.Address

  var source: ImageSource
  var header: Traits.Ehdr
  var programHeaders: [Traits.Phdr]
  var sectionHeaders: [Traits.Shdr]?
  var shouldByteSwap: Bool { return header.shouldByteSwap }

  @_specialize(kind: full, where SomeElfTraits == Elf32Traits)
  @_specialize(kind: full, where SomeElfTraits == Elf64Traits)
  required init(source: ImageSource,
                baseAddress: ImageSource.Address = 0,
                endAddress: ImageSource.Address = 0) throws {
    self.source = source
    self.baseAddress = baseAddress
    self.endAddress = endAddress

    header = try source.fetch(from: 0, as: Traits.Ehdr.self)
    if header.ei_magic != ElfMagic {
      throw ElfImageError.notAnElfImage
    }

    if header.ei_class != Traits.elfClass {
      throw ElfImageError.wrongClass
    }

    if header.shouldByteSwap {
      header = header.byteSwapped
    }

    let byteSwap = header.shouldByteSwap
    func maybeSwap<T: ByteSwappable>(_ x: T) -> T {
      if byteSwap {
        return x.byteSwapped
      }
      return x
    }

    var phdrs: [Traits.Phdr] = []
    var phAddr = ImageSource.Address(header.e_phoff)
    for _ in 0..<header.e_phnum {
      let phdr = maybeSwap(try source.fetch(from: phAddr, as: Traits.Phdr.self))
      phdrs.append(phdr)
      phAddr += ImageSource.Address(header.e_phentsize)
    }
    programHeaders = phdrs

    if source.isMappedImage {
      sectionHeaders = nil
    } else {
      var shdrs: [Traits.Shdr] = []
      var shAddr = ImageSource.Address(header.e_shoff)
      for _ in 0..<header.e_shnum {
        let shdr = maybeSwap(try source.fetch(from: shAddr, as: Traits.Shdr.self))
        shdrs.append(shdr)
        shAddr += ImageSource.Address(header.e_shentsize)
      }
      sectionHeaders = shdrs
    }

    if header.e_shstrndx >= header.e_shnum {
      throw ElfImageError.badStringTableSectionIndex
    }
  }

  struct Note {
    let name: String
    let type: UInt32
    let desc: [UInt8]
  }

  struct Notes: Sequence {
    var image: ElfImage<Traits>

    struct NoteIterator: IteratorProtocol {
      var image: ElfImage<Traits>

      var hdrNdx = -1
      var noteAddr = ImageSource.Address()
      var noteEnd = ImageSource.Address()

      @_specialize(kind: full, where SomeElfTraits == Elf32Traits)
      @_specialize(kind: full, where SomeElfTraits == Elf64Traits)
      init(image: ElfImage<Traits>) {
        self.image = image
      }

      mutating func startHeader() {
        let ph = image.programHeaders[hdrNdx]

        if image.source.isMappedImage {
          noteAddr = ImageSource.Address(ph.p_vaddr)
          noteEnd = noteAddr + ImageSource.Address(ph.p_memsz)
        } else {
          noteAddr = ImageSource.Address(ph.p_offset)
          noteEnd = noteAddr + ImageSource.Address(ph.p_filesz)
        }
      }

      @_specialize(kind: full, where SomeElfTraits == Elf32Traits)
      @_specialize(kind: full, where SomeElfTraits == Elf64Traits)
      mutating func next() -> Note? {
        let byteSwap = image.shouldByteSwap
        func maybeSwap<T: ByteSwappable>(_ x: T) -> T {
          if byteSwap {
            return x.byteSwapped
          }
          return x
        }

        if hdrNdx >= image.programHeaders.count {
          return nil
        }
        while true {
          while noteAddr >= noteEnd {
            repeat {
              hdrNdx += 1
              if hdrNdx >= image.programHeaders.count {
                return nil
              }
            } while image.programHeaders[hdrNdx].p_type != .internal_SWIPR_PT_NOTE
            startHeader()
          }

          do {
            let nhdr = maybeSwap(try image.source.fetch(from: noteAddr,
                                                        as: Traits.Nhdr.self))

            noteAddr += ImageSource.Address(MemoryLayout<Traits.Nhdr>.size)

            if noteEnd - noteAddr < nhdr.n_namesz {
              // The segment is probably corrupted
              noteAddr = noteEnd
              continue
            }

            let nameLen = nhdr.n_namesz > 0 ? nhdr.n_namesz - 1 : 0
            guard let name = try image.source.fetchString(from: noteAddr,
                                                          length: Int(nameLen))
            else {
              // Bad note name
              noteAddr = noteEnd
              continue
            }

            noteAddr += ImageSource.Address(nhdr.n_namesz)
            if (noteAddr & 3) != 0 {
              noteAddr += 4 - (noteAddr & 3)
            }

            if noteEnd - noteAddr < nhdr.n_descsz {
              // The segment is probably corrupted
              noteAddr = noteEnd
              continue
            }

            let desc = try image.source.fetch(from: noteAddr,
                                              count: Int(nhdr.n_descsz),
                                              as: UInt8.self)

            noteAddr += ImageSource.Address(nhdr.n_descsz)
            if (noteAddr & 3) != 0 {
              noteAddr += 4 - (noteAddr & 3)
            }

            return Note(name: name, type: UInt32(nhdr.n_type), desc: desc)
          } catch {
            hdrNdx = image.programHeaders.count
            return nil
          }
        }
      }
    }

    func makeIterator() -> NoteIterator {
      return NoteIterator(image: image)
    }
  }

  var notes: Notes {
    return Notes(image: self)
  }

  private var _uuid: [UInt8]?
  var uuid: [UInt8]? {
    if let uuid = _uuid {
      return uuid
    }

    for note in notes {
      if note.name == "GNU" && note.type == internal_SWIPR_NT_GNU_BUILD_ID {
        _uuid = note.desc
        return _uuid
      }
    }

    return nil
  }

  private var _debugLinkCRC: UInt32?
  var debugLinkCRC: UInt32 {
    if let crc = _debugLinkCRC {
      return crc
    }

    let crc = updateCrc(0, source.bytes)
    _debugLinkCRC = crc
    return crc
  }

  struct Range {
    var base: ImageSource.Address
    var size: ImageSource.Size
  }

  struct EHFrameInfo {
    var ehFrameSection: Range?
    var ehFrameHdrSection: Range?
  }

  private var _ehFrameInfo: EHFrameInfo?
  var ehFrameInfo: EHFrameInfo? {
    if let ehFrameInfo = _ehFrameInfo {
      return ehFrameInfo
    }

    var ehFrameInfo = EHFrameInfo()

    for phdr in programHeaders {
      if phdr.p_type == .internal_SWIPR_PT_GNU_EH_FRAME {
        var ehFrameHdrRange: Range
        if source.isMappedImage {
          ehFrameHdrRange = Range(base: ImageSource.Address(phdr.p_vaddr),
                                  size: ImageSource.Size(phdr.p_memsz))
        } else {
          ehFrameHdrRange = Range(base: ImageSource.Address(phdr.p_offset),
                                  size: ImageSource.Size(phdr.p_filesz))
        }

        if (ehFrameHdrRange.size < MemoryLayout<EHFrameHdr>.size) {
          continue
        }

        guard let ehdr = try? source.fetch(
                from: ImageSource.Address(ehFrameHdrRange.base),
                as: EHFrameHdr.self
              ) else {
          continue
        }

        if ehdr.version != 1 {
          continue
        }

        let pc = ehFrameHdrRange.base + ImageSource.Address(MemoryLayout<EHFrameHdr>.size)
        guard let (_, eh_frame_ptr) =
                try? source.fetchEHValue(from: ImageSource.Address(pc),
                                         with: ehdr.eh_frame_ptr_enc,
                                         pc: ImageSource.Address(pc)) else {
          continue
        }

        ehFrameInfo.ehFrameHdrSection = ehFrameHdrRange

        // The .eh_frame_hdr section doesn't specify the size of the
        // .eh_frame section, so we just rely on it being properly
        // terminated.  This does mean that bulk fetching the entire
        // thing isn't a good idea.
        ehFrameInfo.ehFrameSection = Range(base: ImageSource.Address(eh_frame_ptr),
                                           size: ~ImageSource.Size(0))
      }
    }

    if let sectionHeaders = sectionHeaders {
      let stringShdr = sectionHeaders[Int(header.e_shstrndx)]
      let base = ImageSource.Address(stringShdr.sh_offset)
      let end = base + ImageSource.Size(stringShdr.sh_size)
      let stringSource = source[base..<end]
      let stringSect = ElfStringSection(source: stringSource)

      for shdr in sectionHeaders {
        guard let name = stringSect.getStringAt(index: Int(shdr.sh_name)) else {
          continue
        }

        if name == ".eh_frame" {
          ehFrameInfo.ehFrameSection = Range(base: ImageSource.Address(shdr.sh_offset),
                                             size: ImageSource.Size(shdr.sh_size))
        }
      }
    }

    return ehFrameInfo
  }

  // Image name
  private var _imageName: String?
  var imageName: String {
    if let imageName = _imageName {
      return imageName
    }

    let name: String
    if let path = source.path {
      name = path
    } else if let uuid = uuid {
      name = "image \(hex(uuid))"
    } else {
      name = "<unknown image>"
    }

    _imageName = name
    return name
  }

  // If we have external debug information, this points at it
  private var _checkedDebugImage: Bool?
  private var _debugImage: ElfImage<Traits>?
  var debugImage: ElfImage<Traits>? {
    if let checked = _checkedDebugImage, checked {
      return _debugImage
    }

    let tryPath = { [self] (_ path: String) -> ElfImage<Traits>? in
      do {
        let fileSource = try ImageSource(path: path)
        let image = try ElfImage<Traits>(source: fileSource)
        _debugImage = image
        return image
      } catch {
        return nil
      }
    }

    if let uuid = uuid {
      let uuidString = hex(uuid)
      let uuidSuffix = uuidString.dropFirst(2)
      let uuidPrefix = uuidString.prefix(2)
      let path = "/usr/lib/debug/.build-id/\(uuidPrefix)/\(uuidSuffix).debug"
      if let image = tryPath(path) {
        _debugImage = image
        _checkedDebugImage = true
        return image
      }
    }

    if let imagePath = source.path, let realImagePath = realPath(imagePath) {
      let imageDir = dirname(realImagePath)
      let debugLink = getDebugLink()
      let debugAltLink = getDebugAltLink()

      let tryLink = { (_ link: String) -> ElfImage<Traits>? in
        if let image = tryPath("\(imageDir)/\(link)") {
          return image
        }
        if let image = tryPath("\(imageDir)/.debug/\(link)") {
          return image
        }
        if let image = tryPath("/usr/lib/debug/\(imageDir)/\(link)") {
          return image
        }
        return nil
      }

      if let debugAltLink = debugAltLink, let image = tryLink(debugAltLink.link),
         image.uuid == debugAltLink.uuid {
        _debugImage = image
        _checkedDebugImage = true
        return image
      }

      if let debugLink = debugLink, let image = tryLink(debugLink.link),
         image.debugLinkCRC == debugLink.crc {
        _debugImage = image
        _checkedDebugImage = true
        return image
      }
    }

    _checkedDebugImage = true
    return nil
  }

  /// Find the named section and return an ImageSource pointing at it.
  ///
  /// In general, the section may be compressed or even in a different image;
  /// this is particularly the case for debug sections.  We will only attempt
  /// to look for other images if `debug` is `true`.
  @_specialize(kind: full, where SomeElfTraits == Elf32Traits)
  @_specialize(kind: full, where SomeElfTraits == Elf64Traits)
  func getSection(_ name: String, debug: Bool = false) -> ImageSource? {
    if let sectionHeaders = sectionHeaders {
      let stringShdr = sectionHeaders[Int(header.e_shstrndx)]
      do {
        let base = ImageSource.Address(stringShdr.sh_offset)
        let end = base + ImageSource.Size(stringShdr.sh_size)
        let stringSource = source[base..<end]
        let stringSect = ElfStringSection(source: stringSource)

        for shdr in sectionHeaders {
          guard let sname
                  = stringSect.getStringAt(index: Int(shdr.sh_name)) else {
            continue
          }

          if name == sname {
            let base = ImageSource.Address(shdr.sh_offset)
            let end = base + ImageSource.Size(shdr.sh_size)
            let subSource = source[base..<end]

            if (shdr.sh_flags & Traits.Shdr.Flags(internal_SWIPR_SHF_COMPRESSED)) != 0 {
              () // compression unsupported
              //return try ImageSource(elfCompressedImageSource: subSource,
              //                       traits: Traits.self)
            } else {
              return subSource
            }
          }

        }
      }
    }

    if debug, let image = debugImage {
      return image.getSection(name)
    }

    return nil
  }

  struct DebugLinkInfo {
    var link: String
    var crc: UInt32
  }

  struct DebugAltLinkInfo {
    var link: String
    var uuid: [UInt8]
  }

  /// Get and decode a .gnu_debuglink section
  func getDebugLink() -> DebugLinkInfo? {
    guard let section = getSection(".gnu_debuglink") else {
      return nil
    }

    guard let link = try? section.fetchString(from: 0) else {
      return nil
    }

    let nullIndex = ImageSource.Address(link.utf8.count)
    let crcIndex = (nullIndex + 4) & ~3

    guard let unswappedCrc = try? section.fetch(
            from: crcIndex, as: UInt32.self
          ) else {
      return nil
    }

    let crc: UInt32
    if shouldByteSwap {
      crc = unswappedCrc.byteSwapped
    } else {
      crc = unswappedCrc
    }

    return DebugLinkInfo(link: link, crc: crc)
  }

  /// Get and decode a .gnu_debugaltlink section
  func getDebugAltLink() -> DebugAltLinkInfo? {
    guard let section = getSection(".gnu_debugaltlink") else {
      return nil
    }

    guard let link = try? section.fetchString(from: 0) else {
      return nil
    }

    let nullIndex = link.utf8.count

    let uuid = [UInt8](section.bytes[(nullIndex + 1)...])

    return DebugAltLinkInfo(link: link, uuid: uuid)
  }

  /// Find the named section and read a string out of it.
  func getSectionAsString(_ name: String) -> String? {
    guard let sectionSource = getSection(name) else {
      return nil
    }

    return String(decoding: sectionSource.bytes, as: UTF8.self)
  }

  struct ElfSymbol {
    var name: String
    var value: Traits.Address
    var size: Traits.Size
    var sectionIndex: Int
    var binding: SWIPR_Elf_Sym_Binding
    var type: SWIPR_Elf_Sym_Type
    var visibility: SWIPR_Elf_Sym_Visibility
  }

  var _symbolTable: SymbolTable? = nil
  var symbolTable: SymbolTable { return _getSymbolTable(debug: false) }

  func _getSymbolTable(debug: Bool) -> SymbolTable {
    if let table = _symbolTable {
      return table
    }

    let debugTable: SymbolTable?
    if !debug, let debugImage = debugImage {
      debugTable = debugImage._getSymbolTable(debug: true)
        as any ElfSymbolTableProtocol
        as? SymbolTable
    } else {
      debugTable = nil
    }

    guard let localTable = SymbolTable(image: self) else {
      // If we have no symbol table, try the debug image
      let table = debugTable ?? SymbolTable()
      _symbolTable = table
      return table
    }

    // Check if we have a debug image; if we do, get its symbol table and
    // merge it with this one.  This means that it doesn't matter which
    // symbols have been stripped in both images.
    if let debugTable = debugTable {
      let merged = localTable.merged(with: debugTable)
      _symbolTable = merged
      return merged
    }

    _symbolTable = localTable
    return localTable
  }

  public func lookupSymbol(address: Traits.Address) -> ImageSymbol? {
    let relativeAddress = address - Traits.Address(baseAddress)
    guard let symbol = symbolTable.lookupSymbol(address: relativeAddress) else {
      return nil
    }

    return ImageSymbol(name: symbol.name,
                       offset: Int(relativeAddress - symbol.value))
  }

  func getDwarfSection(_ section: DwarfSection) -> ImageSource? {
    switch section {
      case .debugAbbrev: return getSection(".debug_abbrev")
      case .debugAddr: return getSection(".debug_addr")
      case .debugARanges: return getSection(".debug_aranges")
      case .debugFrame: return getSection(".debug_frame")
      case .debugInfo: return getSection(".debug_info")
      case .debugLine: return getSection(".debug_line")
      case .debugLineStr: return getSection(".debug_line_str")
      case .debugLoc: return getSection(".debug_loc")
      case .debugLocLists: return getSection(".debug_loclists")
      case .debugMacInfo: return getSection(".debug_macinfo")
      case .debugMacro: return getSection(".debug_macro")
      case .debugNames: return getSection(".debug_names")
      case .debugPubNames: return getSection(".debug_pubnames")
      case .debugPubTypes: return getSection(".debug_pubtypes")
      case .debugRanges: return getSection(".debug_ranges")
      case .debugRngLists: return getSection(".debug_rnglists")
      case .debugStr: return getSection(".debug_str")
      case .debugStrOffsets: return getSection(".debug_str_offsets")
      case .debugSup: return getSection(".debug_sup")
      case .debugTypes: return getSection(".debug_types")
      case .debugCuIndex: return getSection(".debug_cu_index")
      case .debugTuIndex: return getSection(".debug_tu_index")
    }
  }

    private lazy var dwarfReader = { [unowned self] in
        try? DwarfReader(source: self, shouldSwap: header.shouldByteSwap)
    }()

  typealias CallSiteInfo = DwarfReader<ElfImage>.CallSiteInfo

  func inlineCallSites(
    at address: Traits.Address
  ) -> ArraySlice<CallSiteInfo> {
    guard let callSiteInfo = dwarfReader?.inlineCallSites else {
      return [][0..<0]
    }

    var min = 0
    var max = callSiteInfo.count

    while min < max {
      let mid = min + (max - min) / 2
      let callSite = callSiteInfo[mid]

      if callSite.lowPC <= address && callSite.highPC > address {
        var first = mid, last = mid
        while first > 0
                && callSiteInfo[first - 1].lowPC <= address
                && callSiteInfo[first - 1].highPC > address {
          first -= 1
        }
        while last < callSiteInfo.count - 1
                && callSiteInfo[last + 1].lowPC <= address
                && callSiteInfo[last + 1].highPC > address {
          last += 1
        }

        return callSiteInfo[first...last]
      } else if callSite.highPC <= address {
        min = mid + 1
      } else if callSite.lowPC > address {
        max = mid
      }
    }

    return []
  }

  

  func sourceLocation(
    for address: Traits.Address
  ) throws -> SourceLocation? {
    var result: SourceLocation? = nil
    var prevState: DwarfLineNumberState? = nil
    guard let dwarfReader = dwarfReader else {
      return nil
    }
    for ndx in 0..<dwarfReader.lineNumberInfo.count {
      var info = dwarfReader.lineNumberInfo[ndx]
      try info.executeProgram { (state, done) in
        if let oldState = prevState,
           address >= oldState.address && address < state.address {
          result = SourceLocation(
            path: oldState.path,
            line: oldState.line,
            column: oldState.column
          )
          done = true
        }

        if state.endSequence {
          prevState = nil
        } else {
          prevState = state
        }
      }
    }

    return result
  }
}

typealias Elf32Image = ElfImage<Elf32Traits>
typealias Elf64Image = ElfImage<Elf64Traits>

// .. Checking for ELF images ..................................................

/// Test if there is a valid ELF image at the specified address; if there is,
/// extract the address range for the text segment and the UUID, if any.


#if os(Linux)

#endif
func getElfImageInfo<R: MemoryReader>(at address: R.Address,
                                      using reader: R)
  -> (endOfText: R.Address, uuid: [UInt8]?)?
{
  do {
    // Check the magic number first
    let magic = try reader.fetch(from: address, as: SWIPR_Elf_Magic.self)

    if magic != ElfMagic {
      return nil
    }

    // Read the class from the next byte
    let elfClass = SWIPR_Elf_Ehdr_Class(rawValue: try reader.fetch(from: address + 4,
                                                             as: UInt8.self))

    if elfClass == .ELFCLASS32 {
      return try getElfImageInfo(at: address, using: reader,
                                 traits: Elf32Traits.self)
    } else if elfClass == .ELFCLASS64 {
      return try getElfImageInfo(at: address, using: reader,
                                 traits: Elf64Traits.self)
    } else {
      return nil
    }
  } catch {
    return nil
  }
}





#if os(Linux)


#endif
func getElfImageInfo<R: MemoryReader, Traits: ElfTraits>(
  at address: R.Address,
  using reader: R,
  traits: Traits.Type
) throws -> (endOfText: R.Address, uuid: [UInt8]?)? {
  // Grab the whole 32-bit header
  let unswappedHeader = try reader.fetch(from: address, as: Traits.Ehdr.self)

  let header: Traits.Ehdr
  if unswappedHeader.shouldByteSwap {
    header = unswappedHeader.byteSwapped
  } else {
    header = unswappedHeader
  }

  let byteSwap = header.shouldByteSwap
  func maybeSwap<T: ByteSwappable>(_ x: T) -> T {
    if byteSwap {
      return x.byteSwapped
    }
    return x
  }

  var endOfText = address
  var uuid: [UInt8]? = nil

  // Find the last loadable executable segment, and scan for internal_SWIPR_PT_NOTE
  // segments that contain the UUID
  var phAddr = ImageSource.Address(address) + ImageSource.Size(header.e_phoff)
  for _ in 0..<header.e_phnum {
    let phdr = maybeSwap(try reader.fetch(from: phAddr, as: Traits.Phdr.self))
    if phdr.p_type == .internal_SWIPR_PT_LOAD && (phdr.p_flags & internal_SWIPR_PF_X) != 0 {
      endOfText = max(endOfText, address + ImageSource.Address(phdr.p_vaddr)
                                   + ImageSource.Size(phdr.p_memsz))
    }
    if phdr.p_type == .internal_SWIPR_PT_NOTE {
      var noteAddr = address + ImageSource.Address(phdr.p_vaddr)
      let noteEnd = noteAddr + ImageSource.Size(phdr.p_memsz)

      while noteAddr < noteEnd {
        let nhdr = maybeSwap(try reader.fetch(
                               from: noteAddr, as: Traits.Nhdr.self))

        noteAddr += ImageSource.Size(MemoryLayout<Traits.Nhdr>.size)

        if noteEnd - noteAddr < nhdr.n_namesz {
          // This segment is probably corrupted, so skip it
          noteAddr = noteEnd
          continue
        }

        var isBuildId = false
        let nameLen = nhdr.n_namesz > 0 ? nhdr.n_namesz - 1 : 0

        // Test if this is a "GNU" internal_SWIPR_NT_GNU_BUILD_ID note
        if nameLen == 3 {
          let byte0 = try reader.fetch(from: noteAddr, as: UInt8.self)
          let byte1 = try reader.fetch(from: noteAddr + 1, as: UInt8.self)
          let byte2 = try reader.fetch(from: noteAddr + 2, as: UInt8.self)

          if byte0 == 0x47 && byte1 == 0x4e && byte2 == 0x55 &&
               UInt32(nhdr.n_type) == internal_SWIPR_NT_GNU_BUILD_ID {
            isBuildId = true
          }
        }

        noteAddr += ImageSource.Size(nhdr.n_namesz)
        if (noteAddr & 3) != 0 {
          noteAddr += 4 - (noteAddr & 3)
        }

        if noteEnd - noteAddr < nhdr.n_descsz {
          // Corrupted segment, skip
          noteAddr = noteEnd
          continue
        }

        if isBuildId {
          uuid = try reader.fetch(from: noteAddr,
                                  count: Int(nhdr.n_descsz),
                                  as: UInt8.self)
        }

        noteAddr += ImageSource.Size(nhdr.n_descsz)
        if (noteAddr & 3) != 0 {
          noteAddr += 4 - (noteAddr & 3)
        }
      }
    }

    phAddr += ImageSource.Address(header.e_phentsize)
  }

  return (endOfText: endOfText, uuid: uuid)
}

// .. Testing ..................................................................

@_spi(ElfTest)
public func testElfImageAt(path: String) -> Bool {
  guard let source = try? ImageSource(path: path) else {
    print("\(path) was not accessible")
    return false
  }

  let debugSections: [String] = [
    ".debug_info",
    ".debug_line",
    ".debug_abbrev",
    ".debug_ranges",
    ".debug_str",
    ".debug_addr",
    ".debug_str_offsets",
    ".debug_line_str",
    ".debug_rnglists"
  ]

  if let elfImage = try? Elf32Image(source: source) {
    print("\(path) is a 32-bit ELF image")

    if let uuid = elfImage.uuid {
      print("  uuid: \(hex(uuid))")
    } else {
      print("  uuid: <no uuid>")
    }

    if let debugImage = elfImage.debugImage {
      print("  debug image: \(debugImage.imageName)")
    } else {
      print("  debug image: <none>")
    }

    for section in debugSections {
      if let _ = elfImage.getSection(section, debug: true) {
        print("  \(section): found")
      } else {
        print("  \(section): not found")
      }
    }

    return true
  } else if let elfImage = try? Elf64Image(source: source) {
    print("\(path) is a 64-bit ELF image")

    if let uuid = elfImage.uuid {
      print("  uuid: \(hex(uuid))")
    } else {
      print("  uuid: <no uuid>")
    }

    if let debugImage = elfImage.debugImage {
      print("  debug image: \(debugImage.imageName)")
    } else {
      print("  debug image: <none>")
    }

    for section in debugSections {
      if let _ = elfImage.getSection(section, debug: true) {
        print("  \(section): found")
      } else {
        print("  \(section): not found")
      }
    }

    return true
  } else {
    print("\(path) is not an ELF image")
    return false
  }
}
