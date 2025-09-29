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

//===--- elf.h - Definitions of ELF structures for import into Swift ------===//
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
// Definitions of ELF structures for import into Swift code
//
// The types here are taken from the System V ABI update, here:
// <http://www.sco.com/developers/gabi/2012-12-31/contents.html>
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_ELF_H
#define SWIFT_ELF_H

#include <inttypes.h>

#ifdef __cplusplus
namespace SWIPRswift {
namespace SWIPRruntime {
#endif

/* .. Useful macros ......................................................... */

#define ELF_ENUM(t,n)   \
  enum __attribute__((enum_extensibility(open))) n: t
#define ELF_OPTIONS(t,n) \
  t n; \
  enum __attribute__((flag_enum,enum_extensibility(open))): t

/* .. Data Representation ................................................... */

// Common sizes (these don't change between 32-bit and 64-bit)
typedef uint8_t  SWIPR_Elf_Byte;
typedef uint16_t SWIPR_Elf_Half;
typedef uint32_t SWIPR_Elf_Word;
typedef uint64_t SWIPR_Elf_Xword;
typedef int32_t  SWIPR_Elf_Sword;
typedef int64_t  SWIPR_Elf_Sxword;

// 32-bit sizes (includes some aliases of the above, for compatibility)
typedef SWIPR_Elf_Byte  SWIPR_Elf32_Byte;
typedef uint32_t  SWIPR_Elf32_Addr;
typedef SWIPR_Elf_Half  SWIPR_Elf32_Half;
typedef uint32_t  SWIPR_Elf32_Off;
typedef SWIPR_Elf_Sword SWIPR_Elf32_Sword;
typedef SWIPR_Elf_Word  SWIPR_Elf32_Word;

// 64-bit sizes (includes some aliases of the above, for compatibility)
typedef SWIPR_Elf_Byte   SWIPR_Elf64_Byte;
typedef uint64_t   SWIPR_Elf64_Addr;
typedef uint64_t   SWIPR_Elf64_Off;
typedef SWIPR_Elf_Half   SWIPR_Elf64_Half;
typedef SWIPR_Elf_Word   SWIPR_Elf64_Word;
typedef SWIPR_Elf_Sword  SWIPR_Elf64_Sword;
typedef SWIPR_Elf_Xword  SWIPR_Elf64_Xword;
typedef SWIPR_Elf_Sxword SWIPR_Elf64_Sxword;

/* .. Constants ............................................................. */

// e_type values
typedef ELF_ENUM(SWIPR_Elf_Half, SWIPR_Elf_Ehdr_Type) {
  internal_SWIPR_ET_NONE   = 0,      // No file type
  internal_SWIPR_ET_REL    = 1,      // Relocatable file
  internal_SWIPR_ET_EXEC   = 2,      // Executable file
  internal_SWIPR_ET_DYN    = 3,      // Shared object file
  internal_SWIPR_ET_CORE   = 4,      // Core file
  internal_SWIPR_ET_LOOS   = 0xfe00, // Operating system specific
  internal_SWIPR_ET_HIOS   = 0xfeff, // Operating system specific
  internal_SWIPR_ET_LOPROC = 0xff00, // Processor specific
  internal_SWIPR_ET_HIPROC = 0xffff, // Processor specific
} SWIPR_Elf_Ehdr_Type;

// e_machine values
typedef ELF_ENUM(SWIPR_Elf_Half, SWIPR_Elf_Ehdr_Machine) {
  internal_SWIPR_EM_NONE          = 0,   // No machine
  internal_SWIPR_EM_M32           = 1,   // AT&T WE 32100
  internal_SWIPR_EM_SPARC         = 2,   // SPARC
  internal_SWIPR_EM_386           = 3,   // Intel 80386
  internal_SWIPR_EM_68K           = 4,   // Motorola 68000
  internal_SWIPR_EM_88K           = 5,   // Motorola 88000

  internal_SWIPR_EM_860           = 7,   // Intel 80860
  internal_SWIPR_EM_MIPS          = 8,   // MIPS I Architecture
  internal_SWIPR_EM_S370          = 9,   // IBM System/370 Processor
  internal_SWIPR_EM_MIPS_RS3_LE   = 10,  // MIPS RS3000 Little-endian

  internal_SWIPR_EM_PARISC        = 15,  // Hewlett-Packard PA-RISC

  internal_SWIPR_EM_VPP500        = 17,  // Fujitsu VPP500
  internal_SWIPR_EM_SPARC32PLUS   = 18,  // Enhanced instruction set SPARC
  internal_SWIPR_EM_960           = 19,  // Intel 80960
  internal_SWIPR_EM_PPC           = 20,  // PowerPC
  internal_SWIPR_EM_PPC64         = 21,  // 64-bit PowerPC
  internal_SWIPR_EM_S390          = 22,  // IBM System/390 Processor
  internal_SWIPR_EM_SPU           = 23,  // IBM SPU/SPC

  internal_SWIPR_EM_V800          = 36,  // NEC V800
  internal_SWIPR_EM_FR20          = 37,  // Fujitsu FR20
  internal_SWIPR_EM_RH32          = 38,  // TRW RH-32
  internal_SWIPR_EM_RCE           = 39,  // Motorola RCE
  internal_SWIPR_EM_ARM           = 40,  // ARM 32-bit architecture (AARCH32)
  internal_SWIPR_EM_ALPHA         = 41,  // Digital Alpha
  internal_SWIPR_EM_SH            = 42,  // Hitachi SH
  internal_SWIPR_EM_SPARCV9       = 43,  // SPARC Version 9
  internal_SWIPR_EM_TRICORE       = 44,  // Siemens TriCore embedded processor
  internal_SWIPR_EM_ARC           = 45,  // Argonaut RISC Core, Argonaut Technologies Inc.
  internal_SWIPR_EM_H8_300        = 46,  // Hitachi H8/300
  internal_SWIPR_EM_H8_300H       = 47,  // Hitachi H8/300H
  internal_SWIPR_EM_H8S           = 48,  // Hitachi H8S
  internal_SWIPR_EM_H8_500        = 49,  // Hitachi H8/500
  internal_SWIPR_EM_IA_64         = 50,  // Intel IA-64 processor architecture
  internal_SWIPR_EM_MIPS_X        = 51,  // Stanford MIPS-X
  internal_SWIPR_EM_COLDFIRE      = 52,  // Motorola ColdFire
  internal_SWIPR_EM_68HC12        = 53,  // Motorola M68HC12
  internal_SWIPR_EM_MMA           = 54,  // Fujitsu MMA Multimedia Accelerator
  internal_SWIPR_EM_PCP           = 55,  // Siemens PCP
  internal_SWIPR_EM_NCPU          = 56,  // Sony nCPU embedded RISC processor
  internal_SWIPR_EM_NDR1          = 57,  // Denso NDR1 microprocessor
  internal_SWIPR_EM_STARCORE      = 58,  // Motorola Star*Core processor
  internal_SWIPR_EM_ME16          = 59,  // Toyota ME16 processor
  internal_SWIPR_EM_ST100         = 60,  // STMicroelectronics ST100 processor
  internal_SWIPR_EM_TINYJ         = 61,  // Advanced Logic Corp. TinyJ embedded processor family
  internal_SWIPR_EM_X86_64        = 62,  // AMD x86-64 architecture
  internal_SWIPR_EM_PDSP          = 63,  // Sony DSP Processor
  internal_SWIPR_EM_PDP10         = 64,  // Digital Equipment Corp. PDP-10
  internal_SWIPR_EM_PDP11         = 65,  // Digital Equipment Corp. PDP-11
  internal_SWIPR_EM_FX66          = 66,  // Siemens FX66 microcontroller
  internal_SWIPR_EM_ST9PLUS       = 67,  // STMicroelectronics ST9+ 8/16 bit microcontroller
  internal_SWIPR_EM_ST7           = 68,  // STMicroelectronics ST7 8-bit microcontroller
  internal_SWIPR_EM_68HC16        = 69,  // Motorola MC68HC16 Microcontroller
  internal_SWIPR_EM_68HC11        = 70,  // Motorola MC68HC11 Microcontroller
  internal_SWIPR_EM_68HC08        = 71,  // Motorola MC68HC08 Microcontroller
  internal_SWIPR_EM_68HC05        = 72,  // Motorola MC68HC05 Microcontroller
  internal_SWIPR_EM_SVX           = 73,  // Silicon Graphics SVx
  internal_SWIPR_EM_ST19          = 74,  // STMicroelectronics ST19 8-bit microcontroller
  internal_SWIPR_EM_VAX           = 75,  // Digital VAX
  internal_SWIPR_EM_CRIS          = 76,  // Axis Communications 32-bit embedded processor
  internal_SWIPR_EM_JAVELIN       = 77,  // Infineon Technologies 32-bit embedded processor
  internal_SWIPR_EM_FIREPATH      = 78,  // Element 14 64-bit DSP Processor
  internal_SWIPR_EM_ZSP           = 79,  // LSI Logic 16-bit DSP Processor
  internal_SWIPR_EM_MMIX          = 80,  // Donald Knuth's educational 64-bit processor
  internal_SWIPR_EM_HUANY         = 81,  // Harvard University machine-independent object files
  internal_SWIPR_EM_PRISM         = 82,  // SiTera Prism
  internal_SWIPR_EM_AVR           = 83,  // Atmel AVR 8-bit microcontroller
  internal_SWIPR_EM_FR30          = 84,  // Fujitsu FR30
  internal_SWIPR_EM_D10V          = 85,  // Mitsubishi D10V
  internal_SWIPR_EM_D30V          = 86,  // Mitsubishi D30V
  internal_SWIPR_EM_V850          = 87,  // NEC v850
  internal_SWIPR_EM_M32R          = 88,  // Mitsubishi M32R
  internal_SWIPR_EM_MN10300       = 89,  // Matsushita MN10300
  internal_SWIPR_EM_MN10200       = 90,  // Matsushita MN10200
  internal_SWIPR_EM_PJ            = 91,  // picoJava
  internal_SWIPR_EM_OPENRISC      = 92,  // OpenRISC 32-bit embedded processor
  internal_SWIPR_EM_ARC_COMPACT   = 93,  // ARC International ARCompact processor (old spelling/synonym: internal_SWIPR_EM_ARC_A5)
  internal_SWIPR_EM_XTENSA        = 94,  // Tensilica Xtensa Architecture
  internal_SWIPR_EM_VIDEOCORE     = 95,  // Alphamosaic VideoCore processor
  internal_SWIPR_EM_TMM_GPP       = 96,  // Thompson Multimedia General Purpose Processor
  internal_SWIPR_EM_NS32K         = 97,  // National Semiconductor 32000 series
  internal_SWIPR_EM_TPC           = 98,  // Tenor Network TPC processor
  internal_SWIPR_EM_SNP1K         = 99,  // Trebia SNP 1000 processor
  internal_SWIPR_EM_ST200         = 100, // STMicroelectronics (www.st.com) ST200 microcontroller
  internal_SWIPR_EM_IP2K          = 101, // Ubicom IP2xxx microcontroller family
  internal_SWIPR_EM_MAX           = 102, // MAX Processor
  internal_SWIPR_EM_CR            = 103, // National Semiconductor CompactRISC microprocessor
  internal_SWIPR_EM_F2MC16        = 104, // Fujitsu F2MC16
  internal_SWIPR_EM_MSP430        = 105, // Texas Instruments embedded microcontroller msp430
  internal_SWIPR_EM_BLACKFIN      = 106, // Analog Devices Blackfin (DSP) processor
  internal_SWIPR_EM_SE_C33        = 107, // S1C33 Family of Seiko Epson processors
  internal_SWIPR_EM_SEP           = 108, // Sharp embedded microprocessor
  internal_SWIPR_EM_ARCA          = 109, // Arca RISC Microprocessor
  internal_SWIPR_EM_UNICORE       = 110, // Microprocessor series from PKU-Unity Ltd. and MPRC of Peking University
  internal_SWIPR_EM_EXCESS        = 111, // eXcess: 16/32/64-bit configurable embedded CPU
  internal_SWIPR_EM_DXP           = 112, // Icera Semiconductor Inc. Deep Execution Processor
  internal_SWIPR_EM_ALTERA_NIOS2  = 113, // Altera Nios II soft-core processor
  internal_SWIPR_EM_CRX           = 114, // National Semiconductor CompactRISC CRX microprocessor
  internal_SWIPR_EM_XGATE         = 115, // Motorola XGATE embedded processor
  internal_SWIPR_EM_C166          = 116, // Infineon C16x/XC16x processor
  internal_SWIPR_EM_M16C          = 117, // Renesas M16C series microprocessors
  internal_SWIPR_EM_DSPIC30F      = 118, // Microchip Technology dsPIC30F Digital Signal Controller
  internal_SWIPR_EM_CE            = 119, // Freescale Communication Engine RISC core
  internal_SWIPR_EM_M32C          = 120, // Renesas M32C series microprocessors

  internal_SWIPR_EM_TSK3000       = 131, // Altium TSK3000 core
  internal_SWIPR_EM_RS08          = 132, // Freescale RS08 embedded processor
  internal_SWIPR_EM_SHARC         = 133, // Analog Devices SHARC family of 32-bit DSP processors
  internal_SWIPR_EM_ECOG2         = 134, // Cyan Technology eCOG2 microprocessor
  internal_SWIPR_EM_SCORE7        = 135, // Sunplus S+core7 RISC processor
  internal_SWIPR_EM_DSP24         = 136, // New Japan Radio (NJR) 24-bit DSP Processor
  internal_SWIPR_EM_VIDEOCORE3    = 137, // Broadcom VideoCore III processor
  internal_SWIPR_EM_LATTICEMICO32 = 138, // RISC processor for Lattice FPGA architecture
  internal_SWIPR_EM_SE_C17        = 139, // Seiko Epson C17 family
  internal_SWIPR_EM_TI_C6000      = 140, // The Texas Instruments TMS320C6000 DSP family
  internal_SWIPR_EM_TI_C2000      = 141, // The Texas Instruments TMS320C2000 DSP family
  internal_SWIPR_EM_TI_C5500      = 142, // The Texas Instruments TMS320C55x DSP family

  internal_SWIPR_EM_MMDSP_PLUS    = 160, // STMicroelectronics 64bit VLIW Data Signal Processor
  internal_SWIPR_EM_CYPRESS_M8C   = 161, // Cypress M8C microprocessor
  internal_SWIPR_EM_R32C          = 162, // Renesas R32C series microprocessors
  internal_SWIPR_EM_TRIMEDIA      = 163, // NXP Semiconductors TriMedia architecture family
  internal_SWIPR_EM_QDSP6         = 164, // QUALCOMM DSP6 Processor
  internal_SWIPR_EM_8051          = 165, // Intel 8051 and variants
  internal_SWIPR_EM_STXP7X        = 166, // STMicroelectronics STxP7x family of configurable and extensible RISC processors
  internal_SWIPR_EM_NDS32         = 167, // Andes Technology compact code size embedded RISC processor family
  internal_SWIPR_EM_ECOG1         = 168, // Cyan Technology eCOG1X family
  internal_SWIPR_EM_ECOG1X        = 168, // Cyan Technology eCOG1X family
  internal_SWIPR_EM_MAXQ30        = 169, // Dallas Semiconductor MAXQ30 Core Micro-controllers
  internal_SWIPR_EM_XIMO16        = 170, // New Japan Radio (NJR) 16-bit DSP Processor
  internal_SWIPR_EM_MANIK         = 171, // M2000 Reconfigurable RISC Microprocessor
  internal_SWIPR_EM_CRAYNV2       = 172, // Cray Inc. NV2 vector architecture
  internal_SWIPR_EM_RX            = 173, // Renesas RX family
  internal_SWIPR_EM_METAG         = 174, // Imagination Technologies META processor architecture
  internal_SWIPR_EM_MCST_ELBRUS   = 175, // MCST Elbrus general purpose hardware architecture
  internal_SWIPR_EM_ECOG16        = 176, // Cyan Technology eCOG16 family
  internal_SWIPR_EM_CR16          = 177, // National Semiconductor CompactRISC CR16 16-bit microprocessor
  internal_SWIPR_EM_ETPU          = 178, // Freescale Extended Time Processing Unit
  internal_SWIPR_EM_SLE9X         = 179, // Infineon Technologies SLE9X core
  internal_SWIPR_EM_L10M          = 180, // Intel L10M
  internal_SWIPR_EM_K10M          = 181, // Intel K10M

  internal_SWIPR_EM_AARCH64       = 183, // ARM 64-bit architecture (AARCH64)

  internal_SWIPR_EM_AVR32         = 185, // Atmel Corporation 32-bit microprocessor family
  internal_SWIPR_EM_STM8          = 186, // STMicroeletronics STM8 8-bit microcontroller
  internal_SWIPR_EM_TILE64        = 187, // Tilera TILE64 multicore architecture family
  internal_SWIPR_EM_TILEPRO       = 188, // Tilera TILEPro multicore architecture family
  internal_SWIPR_EM_MICROBLAZE    = 189, // Xilinx MicroBlaze 32-bit RISC soft processor core
  internal_SWIPR_EM_CUDA          = 190, // NVIDIA CUDA architecture
  internal_SWIPR_EM_TILEGX        = 191, // Tilera TILE-Gx multicore architecture family
  internal_SWIPR_EM_CLOUDSHIELD   = 192, // CloudShield architecture family
  internal_SWIPR_EM_COREA_1ST     = 193, // KIPO-KAIST Core-A 1st generation processor family
  internal_SWIPR_EM_COREA_2ND     = 194, // KIPO-KAIST Core-A 2nd generation processor family
  internal_SWIPR_EM_ARC_COMPACT2  = 195, // Synopsys ARCompact V2
  internal_SWIPR_EM_OPEN8         = 196, // Open8 8-bit RISC soft processor core
  internal_SWIPR_EM_RL78          = 197, // Renesas RL78 family
  internal_SWIPR_EM_VIDEOCORE5    = 198, // Broadcom VideoCore V processor
  internal_SWIPR_EM_78KOR         = 199, // Renesas 78KOR family
  internal_SWIPR_EM_56800EX       = 200, // Freescale 56800EX Digital Signal Controller (DSC)
  internal_SWIPR_EM_BA1           = 201, // Beyond BA1 CPU architecture
  internal_SWIPR_EM_BA2           = 202, // Beyond BA2 CPU architecture
  internal_SWIPR_EM_XCORE         = 203, // XMOS xCORE processor family
  internal_SWIPR_EM_MCHP_PIC      = 204, // Microchip 8-bit PIC(r) family
} SWIPR_Elf_Ehdr_Machine;

// e_version values
typedef ELF_ENUM(SWIPR_Elf_Word, SWIPR_Elf_Ehdr_Version) {
  internal_SWIPR_EV_NONE    = 0, // Invalid version
  internal_SWIPR_EV_CURRENT = 1, // Current version
} SWIPR_Elf_Ehdr_Version;

// e_ident[] identification indices
enum {
  internal_SWIPR_EI_MAG0       = 0, // File identification =     0x7f
  internal_SWIPR_EI_MAG1       = 1, // File identification = 'E' 0x45
  internal_SWIPR_EI_MAG2       = 2, // File identification = 'L' 0x4c
  internal_SWIPR_EI_MAG3       = 3, // File identification = 'F' 0x46
  internal_SWIPR_EI_CLASS      = 4, // File class
  internal_SWIPR_EI_DATA       = 5, // Data encoding
  internal_SWIPR_EI_VERSION    = 6, // File version
  internal_SWIPR_EI_OSABI      = 7, // Operating system/ABI identification
  internal_SWIPR_EI_ABIVERSION = 8, // ABI version
  internal_SWIPR_EI_PAD        = 9, // Start of padding bytes
};

// Magic number
enum : uint8_t {
  ELFMAG0 = 0x7f,
  ELFMAG1 = 'E',
  ELFMAG2 = 'L',
  ELFMAG3 = 'F',
};

// File class
typedef ELF_ENUM(SWIPR_Elf_Byte, SWIPR_Elf_Ehdr_Class) {
  ELFCLASSNONE = 0, // Invalid class
  ELFCLASS32   = 1, // 32-bit objects
  ELFCLASS64   = 2, // 64-bit objects
} SWIPR_Elf_Ehdr_Class;

// Data encoding
typedef ELF_ENUM(SWIPR_Elf_Byte, SWIPR_Elf_Ehdr_Data) {
  ELFDATANONE = 0, // Invalid data encoding
  ELFDATA2LSB = 1, // 2's complement Little Endian
  ELFDATA2MSB = 2, // 2's complement Big Endian
} SWIPR_Elk_Ehdr_Data;

// OS/ABI identification
typedef ELF_ENUM(SWIPR_Elf_Byte, SWIPR_Elf_Ehdr_OsAbi) {
  internal_SWIPR_ELFOSABI_NONE    = 0,  // No extensions or unspecified
  internal_SWIPR_ELFOSABI_HPUX    = 1,  // Hewlett-Packard HP-UX
  internal_SWIPR_ELFOSABI_NETBSD  = 2,  // NetBSD
  internal_SWIPR_ELFOSABI_GNU     = 3,  // GNU
  internal_SWIPR_ELFOSABI_LINUX   = 3,  // Linux (historical - alias for internal_SWIPR_ELFOSABI_GNU)
  internal_SWIPR_ELFOSABI_SOLARIS = 6,  // Sun Solaris
  internal_SWIPR_ELFOSABI_AIX     = 7,  // AIX
  internal_SWIPR_ELFOSABI_IRIX    = 8,  // IRIX
  internal_SWIPR_ELFOSABI_FREEBSD = 9,  // FreeBSD
  internal_SWIPR_ELFOSABI_TRU64   = 10, // Compaq TRU64 UNIX
  internal_SWIPR_ELFOSABI_MODESTO = 11, // Novell Modesto
  internal_SWIPR_ELFOSABI_OPENBSD = 12, // Open BSD
  internal_SWIPR_ELFOSABI_OPENVMS = 13, // Open VMS
  internal_SWIPR_ELFOSABI_NSK     = 14, // Hewlett-Packard Non-Stop Kernel
  internal_SWIPR_ELFOSABI_AROS    = 15, // Amiga Research OS
  internal_SWIPR_ELFOSABI_FENIXOS = 16, // The FenixOS highly scalable multi-core OS
} SWIPR_Elf_Ehdr_OsAbi;

// Special Section Indices
enum {
  internal_SWIPR_SHN_UNDEF     = 0,      // Undefined, missing, irrelevant or meaningless

  internal_SWIPR_SHN_LORESERVE = 0xff00, // Lower bound of reserved indices

  internal_SWIPR_SHN_LOPROC    = 0xff00, // Processor specific
  internal_SWIPR_SHN_HIPROC    = 0xff1f,

  internal_SWIPR_SHN_LOOS      = 0xff20, // OS specific
  internal_SWIPR_SHN_HIOS      = 0xff3f,

  internal_SWIPR_SHN_ABS       = 0xfff1, // Absolute (symbols are not relocated)
  internal_SWIPR_SHN_COMMON    = 0xfff2, // Common
  internal_SWIPR_SHN_XINDEX    = 0xffff, // Indicates section header index is elsewhere

  internal_SWIPR_SHN_HIRESERVE = 0xffff,
};

// Section types
typedef ELF_ENUM(SWIPR_Elf_Word, SWIPR_Elf_Shdr_Type) {
  internal_SWIPR_SHT_NULL          = 0,          // Inactive
  internal_SWIPR_SHT_PROGBITS      = 1,          // Program-defined information
  internal_SWIPR_SHT_SYMTAB        = 2,          // Symbol table
  internal_SWIPR_SHT_STRTAB        = 3,          // String table
  internal_SWIPR_SHT_RELA          = 4,          // Relocation entries with explicit addends
  internal_SWIPR_SHT_HASH          = 5,          // Symbol hash table
  internal_SWIPR_SHT_DYNAMIC       = 6,          // Information for dynamic linking
  internal_SWIPR_SHT_NOTE          = 7,          // Notes
  internal_SWIPR_SHT_NOBITS        = 8,          // Program-defined empty space (bss)
  internal_SWIPR_SHT_REL           = 9,          // Relocation entries without explicit addents
  internal_SWIPR_SHT_SHLIB         = 10,         // Reserved
  internal_SWIPR_SHT_DYNSYM        = 11,
  internal_SWIPR_SHT_INIT_ARRAY    = 14,         // Pointers to initialization functions
  internal_SWIPR_SHT_FINI_ARRAY    = 15,         // Pointers to termination functions
  internal_SWIPR_SHT_PREINIT_ARRAY = 16,         // Pointers to pre-initialization functions
  internal_SWIPR_SHT_GROUP         = 17,         // Defines a section group
  internal_SWIPR_SHT_SYMTAB_SHNDX  = 18,         // Section header indices for symtab

  internal_SWIPR_SHT_LOOS          = 0x60000000, // OS specific
    internal_SWIPR_SHT_GNU_ATTRIBUTES = 0x6ffffff5, // Object attributes
    internal_SWIPR_SHT_GNU_HASH       = 0x6ffffff6, // GNU-style hash table
    internal_SWIPR_SHT_GNU_LIBLIST    = 0x6ffffff7, // Prelink library list
    internal_SWIPR_SHT_CHECKSUM       = 0x6ffffff8, // Checksum for DSK content

    internal_SWIPR_SHT_LOSUNW         = 0x6ffffffa, // Sun-specific
    internal_SWIPR_SHT_SUNW_move      = 0x6ffffffa,
    internal_SWIPR_SHT_SUNW_COMDAT    = 0x6ffffffb,
    internal_SWIPR_SHT_SUNW_syminfo   = 0x6ffffffc,

    internal_SWIPR_SHT_GNU_verdef     = 0x6ffffffd,
    internal_SWIPR_SHT_GNU_verneed    = 0x6ffffffe,
    internal_SWIPR_SHT_GNU_versym     = 0x6fffffff,

    internal_SWIPR_SHT_HISUNW         = 0x6fffffff,
  internal_SWIPR_SHT_HIOS          = 0x6fffffff,

  internal_SWIPR_SHT_LOPROC        = 0x70000000, // Processor specific
  internal_SWIPR_SHT_HIPROC        = 0x7fffffff,

  internal_SWIPR_SHT_LOUSER        = 0x80000000, // Application specific
  internal_SWIPR_SHT_HIUSER        = 0xffffffff,
} SWIPR_Elf_Shdr_Type;

// Section attribute flags (we can't have a type for these because the
// 64-bit section header defines them as 64-bit)
enum {
  internal_SWIPR_SHF_WRITE            = 0x1,        // Writable
  internal_SWIPR_SHF_ALLOC            = 0x2,        // Mapped
  internal_SWIPR_SHF_EXECINSTR        = 0x4,        // Executable instructions
  internal_SWIPR_SHF_MERGE            = 0x10,       // Mergeable elements
  internal_SWIPR_SHF_STRINGS          = 0x20,       // NUL-terminated strings
  internal_SWIPR_SHF_INFO_LINK        = 0x40,       // Section header table index
  internal_SWIPR_SHF_LINK_ORDER       = 0x80,       // Special ordering requirement
  internal_SWIPR_SHF_OS_NONCONFORMING = 0x100,      // OS-specific processing
  internal_SWIPR_SHF_GROUP            = 0x200,      // Section group member
  internal_SWIPR_SHF_TLS              = 0x400,      // Thread Local Storage
  internal_SWIPR_SHF_COMPRESSED       = 0x800,      // Compressed
  internal_SWIPR_SHF_MASKOS           = 0x0ff00000, // Operating system specific flags
  internal_SWIPR_SHF_MASKPROC         = 0xf0000000, // Processor specific flags
};

// Section group flags
enum : SWIPR_Elf_Word {
  internal_SWIPR_GRP_COMDAT   = 0x1,        // COMDAT group
  internal_SWIPR_GRP_MASKOS   = 0x0ff00000, // Operating system specific flags
  internal_SWIPR_GRP_MASKPROC = 0xf0000000, // Processof specific flags
};

// Compression type
typedef ELF_ENUM(SWIPR_Elf_Word, SWIPR_Elf_Chdr_Type) {
  internal_SWIPR_ELFCOMPRESS_ZLIB   = 1,          // DEFLATE algorithm
  internal_SWIPR_ELFCOMPRESS_ZSTD   = 2,          // zstd algorithm

  internal_SWIPR_ELFCOMPRESS_LOOS   = 0x60000000, // Operating system specific
  internal_SWIPR_ELFCOMPRESS_HIOS   = 0x6fffffff,

  internal_SWIPR_ELFCOMPRESS_LOPROC = 0x70000000, // Processor specific
  internal_SWIPR_ELFCOMPRESS_HIPROC = 0x7fffffff
} SWIPR_Elf_Chdr_Type;

// Symbol table entry
enum : SWIPR_Elf_Word {
  internal_SWIPR_STN_UNDEF = 0
};

typedef ELF_ENUM(SWIPR_Elf_Byte, SWIPR_Elf_Sym_Binding) {
  internal_SWIPR_STB_LOCAL  = 0,
  internal_SWIPR_STB_GLOBAL = 1,
  internal_SWIPR_STB_WEAK   = 2,

  internal_SWIPR_STB_LOOS   = 10, // Operating system specific
  internal_SWIPR_STB_HIOS   = 12,

  internal_SWIPR_STB_LOPROC = 13, // Processor specific
  internal_SWIPR_STB_HIPROC = 15
} SWIPR_Elf_Sym_Binding;

typedef ELF_ENUM(SWIPR_Elf_Byte, SWIPR_Elf_Sym_Type) {
  internal_SWIPR_STT_NOTYPE  = 0,  // Unspecified
  internal_SWIPR_STT_OBJECT  = 1,  // Data object (variable, array, &c)
  internal_SWIPR_STT_FUNC    = 2,  // Function or other executable code
  internal_SWIPR_STT_SECTION = 3,  // A section
  internal_SWIPR_STT_FILE    = 4,  // Source file name
  internal_SWIPR_STT_COMMON  = 5,  // Uninitialized common block
  internal_SWIPR_STT_TLS     = 6,  // Thread Local Storage

  internal_SWIPR_STT_LOOS    = 10, // Operating system specific
  internal_SWIPR_STT_HIOS    = 12,

  internal_SWIPR_STT_LOPROC  = 13, // Processor specific
  internal_SWIPR_STT_HIPROC  = 15,
} SWIPR_Elf_Sym_Type;

typedef ELF_ENUM(SWIPR_Elf_Byte, SWIPR_Elf_Sym_Visibility) {
  internal_SWIPR_STV_DEFAULT   = 0,
  internal_SWIPR_STV_INTERNAL  = 1, // Processor specific but like hidden
  internal_SWIPR_STV_HIDDEN    = 2, // Not visible from other components
  internal_SWIPR_STV_PROTECTED = 3, // Visible but cannot be preempted
} SWIPR_Elf_Sym_Visibility;

// Program header types
typedef ELF_ENUM(SWIPR_Elf_Word, SWIPR_Elf_Phdr_Type) {
  internal_SWIPR_PT_NULL    = 0,          // Element unused
  internal_SWIPR_PT_LOAD    = 1,          // Loadable segment
  internal_SWIPR_PT_DYNAMIC = 2,          // Dynamic linking information
  internal_SWIPR_PT_INTERP  = 3,          // Interpreter
  internal_SWIPR_PT_NOTE    = 4,          // Auxiliary information
  internal_SWIPR_PT_SHLIB   = 5,          // Reserved
  internal_SWIPR_PT_PHDR    = 6,          // Program header table
  internal_SWIPR_PT_TLS     = 7,          // Thread Local Storage

  internal_SWIPR_PT_LOOS    = 0x60000000, // Operating system specific
    internal_SWIPR_PT_GNU_EH_FRAME = 0x6474e550, // GNU .eh_frame_hdr segment
    internal_SWIPR_PT_GNU_STACK    = 0x6474e551, // Indicates stack executability
    internal_SWIPR_PT_GNU_RELRO    = 0x6474e552, // Read-only after relocation

    internal_SWIPR_PT_LOSUNW       = 0x6ffffffa,
    internal_SWIPR_PT_SUNWBSS      = 0x6ffffffa,
    internal_SWIPR_PT_SUNWSTACK    = 0x6ffffffb,
    internal_SWIPR_PT_HISUNW       = 0x6fffffff,
  internal_SWIPR_PT_HIOS    = 0x6fffffff,

  internal_SWIPR_PT_LOPROC  = 0x70000000, // Processor specific
  internal_SWIPR_PT_HIPROC  = 0x7fffffff,
} SWIPR_Elf_Phdr_Type;

// Program header flags
typedef ELF_OPTIONS(SWIPR_Elf_Word, SWIPR_Elf_Phdr_Flags) {
  internal_SWIPR_PF_X        = 0x1,        // Execute
  internal_SWIPR_PF_W        = 0x2,        // Write
  internal_SWIPR_PF_R        = 0x4,        // Read,

  internal_SWIPR_PF_MASKOS   = 0x0ff00000, // Operating system specific
  internal_SWIPR_PF_MASKPROC = 0xf0000000, // Processor specific
};

// Dynamic linking tags
enum {
  internal_SWIPR_DT_NULL            = 0,  // Marks the end of the _DYNAMIC array
  internal_SWIPR_DT_NEEDED          = 1,  // String table offset of name of needed library
  internal_SWIPR_DT_PLTRELSZ        = 2,  // Total size of relocation entries for PLT
  internal_SWIPR_DT_PLTGOT          = 3,  // Address of PLT/GOT
  internal_SWIPR_DT_HASH            = 4,  // Address of symbol hash table
  internal_SWIPR_DT_STRTAB          = 5,  // Address of string table
  internal_SWIPR_DT_SYMTAB          = 6,  // Address of symbol table
  internal_SWIPR_DT_RELA            = 7,  // Address of internal_SWIPR_DT_RELA relocation table
  internal_SWIPR_DT_RELASZ          = 8,  // Size of internal_SWIPR_DT_RELA table
  internal_SWIPR_DT_RELAENT         = 9,  // Size of internal_SWIPR_DT_RELA entry
  internal_SWIPR_DT_STRSZ           = 10, // Size of string table
  internal_SWIPR_DT_SYMENT          = 11, // Size of symbol table entry
  internal_SWIPR_DT_INIT            = 12, // Address of initialization function
  internal_SWIPR_DT_FINI            = 13, // Address of termination function
  internal_SWIPR_DT_SONAME          = 14, // String table offset of name of shared object
  internal_SWIPR_DT_RPATH           = 15, // String table offset of search path
  internal_SWIPR_DT_SYMBOLIC        = 16, // Means to search from shared object first
  internal_SWIPR_DT_REL             = 17, // Address of internal_SWIPR_DT_REL relocation table
  internal_SWIPR_DT_RELSZ           = 18, // Size of internal_SWIPR_DT_REL table
  internal_SWIPR_DT_RELENT          = 19, // Size of internal_SWIPR_DT_REL entry
  internal_SWIPR_DT_PLTREL          = 20, // Type of PLT relocation entry (internal_SWIPR_DT_REL/internal_SWIPR_DT_RELA)
  internal_SWIPR_DT_DEBUG           = 21, // Used for debugging
  internal_SWIPR_DT_TEXTREL         = 22, // Means relocations might write to read-only segment
  internal_SWIPR_DT_JMPREL          = 23, // Address of relocation entries for PLT
  internal_SWIPR_DT_BIND_NOW        = 24, // Means linker should not lazily bind
  internal_SWIPR_DT_INIT_ARRAY      = 25, // Address of pointers to initialization functions
  internal_SWIPR_DT_FINI_ARRAY      = 26, // Address of pointers to termination functions
  internal_SWIPR_DT_INIT_ARRAYSZ    = 27, // Size in bytes of initialization function array
  internal_SWIPR_DT_FINI_ARRAYSZ    = 28, // Size in bytes of termination function array
  internal_SWIPR_DT_RUNPATH         = 29, // String table offset of search path
  internal_SWIPR_DT_FLAGS           = 30, // Flags

  internal_SWIPR_DT_ENCODING        = 32, // Tags equal to or above this follow encoding rules

  internal_SWIPR_DT_PREINIT_ARRAY   = 32, // Address of pre-initialization function array
  internal_SWIPR_DT_PREINIT_ARRAYSZ = 33, // Size in bytes of pre-initialization fn array

  internal_SWIPR_DT_LOOS            = 0x6000000D, // Operating system specific
  internal_SWIPR_DT_HIOS            = 0x6ffff000,

  internal_SWIPR_DT_LOPROC          = 0x70000000, // Processor specific
  internal_SWIPR_DT_HIPROC          = 0x7fffffff,
};

// Dynamic linking flags
enum {
  internal_SWIPR_DF_ORIGIN     = 0x1,  // Uses $ORIGIN substitution string
  internal_SWIPR_DF_SYMBOLIC   = 0x2,  // Search shared object first before usual search
  internal_SWIPR_DF_TEXTREL    = 0x4,  // Relocations may modify read-only segments
  internal_SWIPR_DF_BIND_NOW   = 0x8,  // Linker should not lazily bind
  internal_SWIPR_DF_STATIC_TLS = 0x10, // Uses static TLS - must not be dynamically loaded
};

// GNU note types
enum {
  internal_SWIPR_NT_GNU_ABI_TAG         = 1, // ABI information
  internal_SWIPR_NT_GNU_HWCAP           = 2, // Synthetic hwcap information
  internal_SWIPR_NT_GNU_BUILD_ID        = 3, // Build ID
  internal_SWIPR_NT_GNU_GOLD_VERSION    = 4, // Generated by GNU gold
  internal_SWIPR_NT_GNU_PROPERTY_TYPE_0 = 5, // Program property
};

/* .. ELF Header ............................................................ */

#define internal_SWIPR_EI_NIDENT 16

typedef struct {
  SWIPR_Elf32_Byte       e_ident[internal_SWIPR_EI_NIDENT];
  SWIPR_Elf_Ehdr_Type    e_type;
  SWIPR_Elf_Ehdr_Machine e_machine;
  SWIPR_Elf_Ehdr_Version e_version;
  SWIPR_Elf32_Addr       e_entry;
  SWIPR_Elf32_Off        e_phoff;
  SWIPR_Elf32_Off        e_shoff;
  SWIPR_Elf32_Word       e_flags;
  SWIPR_Elf32_Half       e_ehsize;
  SWIPR_Elf32_Half       e_phentsize;
  SWIPR_Elf32_Half       e_phnum;
  SWIPR_Elf32_Half       e_shentsize;
  SWIPR_Elf32_Half       e_shnum;
  SWIPR_Elf32_Half       e_shstrndx;
} SWIPR_Elf32_Ehdr;

typedef struct {
  SWIPR_Elf64_Byte       e_ident[internal_SWIPR_EI_NIDENT];
  SWIPR_Elf_Ehdr_Type    e_type;
  SWIPR_Elf_Ehdr_Machine e_machine;
  SWIPR_Elf_Ehdr_Version e_version;
  SWIPR_Elf64_Addr       e_entry;
  SWIPR_Elf64_Off        e_phoff;
  SWIPR_Elf64_Off        e_shoff;
  SWIPR_Elf64_Word       e_flags;
  SWIPR_Elf64_Half       e_ehsize;
  SWIPR_Elf64_Half       e_phentsize;
  SWIPR_Elf64_Half       e_phnum;
  SWIPR_Elf64_Half       e_shentsize;
  SWIPR_Elf64_Half       e_shnum;
  SWIPR_Elf64_Half       e_shstrndx;
} SWIPR_Elf64_Ehdr;

/* .. Section Header ........................................................ */

typedef struct {
  SWIPR_Elf32_Word    sh_name;
  SWIPR_Elf_Shdr_Type sh_type;
  SWIPR_Elf32_Word    sh_flags;
  SWIPR_Elf32_Addr    sh_addr;
  SWIPR_Elf32_Off     sh_offset;
  SWIPR_Elf32_Word    sh_size;
  SWIPR_Elf32_Word    sh_link;
  SWIPR_Elf32_Word    sh_info;
  SWIPR_Elf32_Word    sh_addralign;
  SWIPR_Elf32_Word    sh_entsize;
} SWIPR_Elf32_Shdr;

typedef struct {
  SWIPR_Elf64_Word    sh_name;
  SWIPR_Elf_Shdr_Type sh_type;
  SWIPR_Elf64_Xword   sh_flags;
  SWIPR_Elf64_Addr    sh_addr;
  SWIPR_Elf64_Off     sh_offset;
  SWIPR_Elf64_Xword   sh_size;
  SWIPR_Elf64_Word    sh_link;
  SWIPR_Elf64_Word    sh_info;
  SWIPR_Elf64_Xword   sh_addralign;
  SWIPR_Elf64_Xword   sh_entsize;
} SWIPR_Elf64_Shdr;

/* .. Compression Header .................................................... */

typedef struct {
  SWIPR_Elf_Chdr_Type ch_type;
  SWIPR_Elf32_Word    ch_size;
  SWIPR_Elf32_Word    ch_addralign;
} SWIPR_Elf32_Chdr;

typedef struct {
  SWIPR_Elf_Chdr_Type ch_type;
  SWIPR_Elf64_Word    ch_reserved;
  SWIPR_Elf64_Xword   ch_size;
  SWIPR_Elf64_Xword   ch_addralign;
} SWIPR_Elf64_Chdr;

/* .. Symbol Table .......................................................... */

typedef struct {
  SWIPR_Elf32_Word st_name;
  SWIPR_Elf32_Addr st_value;
  SWIPR_Elf32_Word st_size;
  SWIPR_Elf32_Byte st_info;
  SWIPR_Elf32_Byte st_other;
  SWIPR_Elf32_Half st_shndx;
} SWIPR_Elf32_Sym;

typedef struct {
  SWIPR_Elf64_Word  st_name;
  SWIPR_Elf64_Byte  st_info;
  SWIPR_Elf64_Byte  st_other;
  SWIPR_Elf64_Half  st_shndx;
  SWIPR_Elf64_Addr  st_value;
  SWIPR_Elf64_Xword st_size;
} SWIPR_Elf64_Sym;

static inline SWIPR_Elf_Sym_Binding ELF32_ST_BIND(SWIPR_Elf_Byte i) {
  return (SWIPR_Elf_Sym_Binding)(i >> 4);
}
static inline SWIPR_Elf_Sym_Type ELF32_ST_TYPE(SWIPR_Elf_Byte i) {
  return (SWIPR_Elf_Sym_Type)(i & 0xf);
}
static inline SWIPR_Elf_Byte ELF32_ST_INFO(SWIPR_Elf_Sym_Binding b, SWIPR_Elf_Sym_Type t) {
  return (SWIPR_Elf_Byte)((b << 4) | (t & 0xf));
}

static inline SWIPR_Elf_Sym_Binding ELF64_ST_BIND(SWIPR_Elf_Byte i) {
  return (SWIPR_Elf_Sym_Binding)(i >> 4);
}
static inline SWIPR_Elf_Sym_Type ELF64_ST_TYPE(SWIPR_Elf_Byte i) {
  return (SWIPR_Elf_Sym_Type)(i & 0xf);
}
static inline SWIPR_Elf_Byte ELF64_ST_INFO(SWIPR_Elf_Sym_Binding b, SWIPR_Elf_Sym_Type t) {
  return (SWIPR_Elf_Byte)((b << 4) | (t & 0xf));
}

static inline SWIPR_Elf_Sym_Visibility ELF32_ST_VISIBILITY(SWIPR_Elf_Byte o) {
  return (SWIPR_Elf_Sym_Visibility)(o & 3);
}
static inline SWIPR_Elf_Sym_Visibility ELF64_ST_VISIBILITY(SWIPR_Elf_Byte o) {
  return (SWIPR_Elf_Sym_Visibility)(o & 3);
}

/* .. Relocation ............................................................ */

typedef struct {
  SWIPR_Elf32_Addr    r_offset;
  SWIPR_Elf32_Word    r_info;
} SWIPR_Elf32_Rel;

typedef struct {
  SWIPR_Elf32_Addr    r_offset;
  SWIPR_Elf32_Word    r_info;
  SWIPR_Elf32_Sword   r_addend;
} SWIPR_Elf32_Rela;

typedef struct {
  SWIPR_Elf64_Addr    r_offset;
  SWIPR_Elf64_Xword   r_info;
} SWIPR_Elf64_Rel;

typedef struct {
  SWIPR_Elf64_Addr    r_offset;
  SWIPR_Elf64_Xword   r_info;
  SWIPR_Elf64_Sxword  r_addend;
} SWIPR_Elf64_Rela;

static inline SWIPR_Elf32_Byte ELF32_R_SYM(SWIPR_Elf32_Word i) { return i >> 8; }
static inline SWIPR_Elf32_Byte ELF32_R_TYPE(SWIPR_Elf32_Word i) { return i & 0xff; }
static inline SWIPR_Elf32_Word ELF32_R_INFO(SWIPR_Elf32_Byte s, SWIPR_Elf32_Byte t) {
  return (s << 8) | t;
}

static inline SWIPR_Elf64_Word ELF64_R_SYM(SWIPR_Elf64_Xword i) { return i >> 32; }
static inline SWIPR_Elf64_Word ELF64_R_TYPE(SWIPR_Elf64_Xword i) { return i & 0xffffffff; }
static inline SWIPR_Elf64_Xword ELF64_R_INFO(SWIPR_Elf64_Word s, SWIPR_Elf64_Word t) {
  return (((SWIPR_Elf64_Xword)s) << 32) | t;
}

/* .. Program Header ........................................................ */

typedef struct {
  SWIPR_Elf_Phdr_Type   p_type;
  SWIPR_Elf32_Off       p_offset;
  SWIPR_Elf32_Addr      p_vaddr;
  SWIPR_Elf32_Addr      p_paddr;
  SWIPR_Elf32_Word      p_filesz;
  SWIPR_Elf32_Word      p_memsz;
  SWIPR_Elf_Phdr_Flags  p_flags;
  SWIPR_Elf32_Word      p_align;
} SWIPR_Elf32_Phdr;

typedef struct {
  SWIPR_Elf_Phdr_Type   p_type;
  SWIPR_Elf_Phdr_Flags  p_flags;
  SWIPR_Elf64_Off       p_offset;
  SWIPR_Elf64_Addr      p_vaddr;
  SWIPR_Elf64_Addr      p_paddr;
  SWIPR_Elf64_Xword     p_filesz;
  SWIPR_Elf64_Xword     p_memsz;
  SWIPR_Elf64_Xword     p_align;
} SWIPR_Elf64_Phdr;

/* .. Note Header ........................................................... */

typedef struct {
  SWIPR_Elf32_Word n_namesz;
  SWIPR_Elf32_Word n_descsz;
  SWIPR_Elf32_Word n_type;
} SWIPR_Elf32_Nhdr;

typedef struct {
  SWIPR_Elf64_Word n_namesz;
  SWIPR_Elf64_Word n_descsz;
  SWIPR_Elf64_Word n_type;
} SWIPR_Elf64_Nhdr;

/* .. Dynamic Linking ....................................................... */

typedef struct {
  SWIPR_Elf32_Sword   d_tag;
  union {
    SWIPR_Elf32_Word  d_val;
    SWIPR_Elf32_Addr  d_ptr;
  } d_un;
} SWIPR_Elf32_Dyn;

typedef struct {
  SWIPR_Elf64_Sxword  d_tag;
  union {
    SWIPR_Elf64_Xword d_val;
    SWIPR_Elf64_Addr  d_ptr;
  } d_un;
} SWIPR_Elf64_Dyn;

/* .. Hash Table ............................................................ */

typedef struct {
  SWIPR_Elf32_Word h_nbucket;
  SWIPR_Elf32_Word h_nchain;
} SWIPR_Elf32_Hash;

typedef struct {
  SWIPR_Elf64_Word h_nbucket;
  SWIPR_Elf64_Word h_nchain;
} SWIPR_Elf64_Hash;

static inline unsigned long
SWIPR_elf_hash(const unsigned char *name)
{
  unsigned long h = 0, g;
  while (*name) {
    h = (h << 4) + *name++;
    if ((g = h & 0xf0000000))
      h ^= g >> 24;
    h &= ~g;
  }
  return h;
}

#ifdef __cplusplus
} // namespace SWIPRruntime
} // namespace SWIPRswift
#endif

#endif // ELF_H
