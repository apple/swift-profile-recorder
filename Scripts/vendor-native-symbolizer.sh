#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Profile Recorder open source project
##
## Copyright (c) 2024 Apple Inc. and the Swift Profile Recorder project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

set -eu

here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
swift_root=${1:-$here/../../swift}
backtracing_root="$swift_root"/stdlib/public/RuntimeModule
prefix=${2:-SWIPR}

function die() {
    echo "ERROR: $*"
    exit 1
}

echo "Using backtracing_root from $backtracing_root"
test -d "$backtracing_root" || die "$backtracing_root: Not found"

target_c_src="$here/../Sources/CProfileRecorderSwiftELF"
target_swift_src="$here/../Sources/ProfileRecorderSampleConversion/NativeELFSymboliser"
desc=$(cd "$backtracing_root" && git describe --abbrev --dirty)

rm -rf "$target_c_src" "$target_swift_src"
mkdir -p "$target_c_src/include"
mkdir -p "$target_swift_src"
cat > "$target_c_src/empty.c" <<"EOF"
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
EOF

cp "$backtracing_root"/modules/ImageFormats/Elf/*.h "$target_c_src/include/"
cp "$backtracing_root"/modules/ImageFormats/Dwarf/*.h "$target_c_src/include/"
cp "$backtracing_root"/modules/ImageFormats/PeCoff/*.h "$target_c_src/include/"
cp "$backtracing_root"/modules/ImageFormats/CodeView/*.h "$target_c_src/include/"
cp "$backtracing_root"/modules/ImageFormats/PDB/*.h "$target_c_src/include/"
cp "$backtracing_root"/modules/Compression.h "$target_c_src/include/"
cp "$backtracing_root"/modules/OS/Libc.h "$target_c_src/include/"
for f in "$target_c_src/include"/*.h; do
    # Some headers are only ever compiled as C++ upstream, guard their namespaces and add typedefs for their enums
    # so they also work as C
    awk '
    /^(namespace swift \{|\} \/\/ namespace runtime)$/ && prev != "#ifdef __cplusplus" {
        print "#ifdef __cplusplus"
        print
        getline
        print
        print "#endif"
        prev = "#endif"
        next
    }
    /^PE_ENUM\([^,]+, [a-z_]+\) \{$/ {
        enum_name = $2
        sub(/\)$/, "", enum_name)
    }
    enum_name != "" && /^};$/ {
        print
        print "typedef enum " enum_name " " enum_name ";"
        enum_name = ""
        prev = ""
        next
    }
    { print; prev = $0 }
    ' "$f" > "$(dirname "$f")/swipr-$(basename "$f")"
    rm "$f"
done

cat > "$target_c_src/include/CProfileRecorderSwiftELF.h" <<"EOF"
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#ifndef CProfileRecorderSWIFTELF_h
#define CProfileRecorderSWIFTELF_h

#include "swipr-elf.h"
#include "swipr-eh_frame_hdr.h"
#include "swipr-dwarf.h"
#include "swipr-pe-coff.h"
#include "swipr-codeview.h"
#include "swipr-pdb.h"
#include "swipr-Compression.h"
#include "swipr-Libc.h"

#endif
EOF

swift_files=(
    AggregatingSymbolSource.swift
    BacktracerThreadLocals.swift
    ByteSwapping.swift
    Compression.swift
    DefaultSymbolLocator.swift
    Dwarf.swift
    Elf.swift
    ElfImageCache.swift
    Image.swift
    ImageSource.swift
    Libc.swift
    MemoryReader.swift
    PDBCache.swift
    PeCoff.swift
    PeImageCache.swift
    Registers.swift
    SymbolLocator.swift
    Utils.swift
)

for f in "${swift_files[@]}"; do
    cp "$backtracing_root/$f" "$target_swift_src"
done
mkdir -p "$target_swift_src/PDB"
cp "$backtracing_root"/PDB/*.swift "$target_swift_src/PDB"
# The PDB code needs Swift 6.2 (`unsafe` expressions, `Span`), older compilers get the stubs in
# ProfileRecorderAddtions+Types.swift (PDB files are only used on Windows anyway)
for f in "$target_swift_src"/PDB/*.swift "$target_swift_src/PDBCache.swift"; do
    { echo "#if compiler(>=6.2)"; cat "$f"; echo "#endif"; } > "$f.tmp" && mv "$f.tmp" "$f"
done
echo "$desc" > "$here/../Misc/vendored-backtracing_root.version"

vendored_file_text='//===----------------------------------------------------------------------===//
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
'

find "$target_c_src" "$target_swift_src" \
    -type f \
    -exec gsed -ri \
        -e "s/namespace ([A-Za-z0-9]+)/namespace ${prefix}\1/g" \
        -e "s/\<elf_/${prefix}_elf_/g" \
        -e "s/\<Elf_/${prefix}_Elf_/g" \
        -e "s/\<Elk_/${prefix}_Elk_/g" \
        -e "s/\<Elf64_/${prefix}_Elf64_/g" \
        -e "s/\<Elf32_/${prefix}_Elf32_/g" \
        -e "s/\<Dwarf_/${prefix}_Dwarf_/g" \
        -e "s/\<Dwarf32_/${prefix}_Dwarf32_/g" \
        -e "s/\<Dwarf64_/${prefix}_Dwarf64_/g" \
        -e "s/\<DF_/internal_${prefix}_DF_/g" \
        -e "s/\<DT_/internal_${prefix}_DT_/g" \
        -e "s/\<DW_/internal_${prefix}_DW_/g" \
        -e "s/\<DWARF_/internal_${prefix}_DWARF_/g" \
        -e "s/\<EI_/internal_${prefix}_EI_/g" \
        -e "s/\<ELFCOMPRESS_/internal_${prefix}_ELFCOMPRESS_/g" \
        -e "s/\<ELFOSABI_/internal_${prefix}_ELFOSABI_/g" \
        -e "s/\<EM_/internal_${prefix}_EM_/g" \
        -e "s/\<ET_/internal_${prefix}_ET_/g" \
        -e "s/\<EV_/internal_${prefix}_EV_/g" \
        -e "s/\<GRP_/internal_${prefix}_GRP_/g" \
        -e "s/\<NT_/internal_${prefix}_NT_/g" \
        -e "s/\<PF_/internal_${prefix}_PF_/g" \
        -e "s/\<PT_/internal_${prefix}_PT_/g" \
        -e "s/\<SHF_/internal_${prefix}_SHF_/g" \
        -e "s/\<SHN_/internal_${prefix}_SHN_/g" \
        -e "s/\<SHT_/internal_${prefix}_SHT_/g" \
        -e "s/\<STB_/internal_${prefix}_STB_/g" \
        -e "s/\<STN_/internal_${prefix}_STN_/g" \
        -e "s/\<STT_/internal_${prefix}_STT_/g" \
        -e "s/\<STV_/internal_${prefix}_STV_/g" \
        -e "s/\<z_stream(_s|p)?\>/${prefix}_z_stream\1/g" \
        -e "s/\<(Z_OK|Z_STREAM_END|Z_NO_FLUSH|ZLIB_VERSION)\>/internal_${prefix}_\1/g" \
        -e "s/\<ZSTD_(in|out)Buffer(_s)?\>/${prefix}_ZSTD_\1Buffer\2/g" \
        -e "s/\<lzma_(ret|action|allocator|internal|internal_s|reserved_enum|stream)\>/${prefix}_lzma_\1/g" \
        -e "s/\<LZMA_/internal_${prefix}_LZMA_/g" \
        -e "s/\<(lzma|zlib)_stream_init\>/${prefix}_\1_stream_init/g" \
        -e "s/@available(.*)//g" \
        -e "s/import Swift//g" \
        -e "s/^let ELF64_/nonisolated(unsafe) let ELF64_/g" \
        -e "s/^let ELF32_/nonisolated(unsafe) let ELF32_/g" \
        -e "s/^let elf_/nonisolated(unsafe) let elf_/g" \
        -e "s/os\(linux\)/os(Linux)/g" \
        -e "s/internal import BacktracingImpl.ImageFormats.Dwarf/import CProfileRecorderSwiftELF/g" \
        -e "s/internal import BacktracingImpl.Runtime//g" \
        -e "s/internal import BacktracingImpl.ImageFormats.Elf/import CProfileRecorderSwiftELF/g" \
        -e "s/internal import BacktracingImpl.OS.Darwin//g" \
        -e "s/internal import BacktracingImpl.OS.SafeReadMemory//g" \
        -e "s/@_implementationOnly import BacktracingImpl\.(ImageFormats\.[A-Za-z]+|CompressionLibs|OS\.Libc)$/import CProfileRecorderSwiftELF/g" \
        -e "s/@_implementationOnly import BacktracingImpl\.(OS\.[A-Za-z]+|Runtime)$//g" \
        -e "s/swift\.runtime\.backtrace\./CProfileRecorderSwiftELF./g" \
        -e "s/swift\.runtime\./CProfileRecorderSwiftELF./g" \
        -e "s/internal import/import/g" \
        -e "s/\<_swift_(open|get_errno|set_errno)\>/${prefix}_swift_\1/g" \
        -e "s/mach_task_self\(\)/mach_task_self_/g" \
        -e "s/SymbolicatedBacktrace\.SourceLocation/_ProfileRecorderSampleConversion.SourceLocation/g" \
        -e "s/@_specialize\(kind: full, where R == RemoteMemoryReader\)//g" \
        -e "s/@_specialize\(kind: full, where R == MemserverMemoryReader\)//g" \
        -e "s/@_specialize\(kind: full, where R == RemoteMemoryReader, Traits == Elf32Traits\)//g" \
        -e "s/@_specialize\(kind: full, where R == RemoteMemoryReader, Traits == Elf64Traits\)//g" \
        -e "s/@_specialize\(kind: full, where R == MemserverMemoryReader, Traits == Elf32Traits\)//g" \
        -e "s/@_specialize\(kind: full, where R == MemserverMemoryReader, Traits == Elf64Traits\)//g" \
        -e "s/@_specialize\(kind: full, where R == UnsafeLocalMemoryReader\)//g" \
        -e "s/@_specialize\(kind: full, where R == UnsafeLocalMemoryReader, Traits == Elf32Traits\)//g" \
        -e "s/@_specialize\(kind: full, where R == UnsafeLocalMemoryReader, Traits == Elf64Traits\)//g" \
        -e "s/^#if os\(macOS\) \|\| os\(iOS\) \|\| os\(tvOS\) \|\| os\(watchOS\)$/#if canImport(Darwin)/g" \
        -e "s/^#if os\(anyAppleOS\)$/#if canImport(Darwin)/g" \
        -e "s/[[:space:]]+$//" \
        -e "1s%^%$(echo "$vendored_file_text" | tr '\n' '%' | sed 's/%/\\n/g')%" \
        '{}' \;

# vendor-core-symbolication-symbolizer.sh makes CoreSymbolication.swift's `Sym` internal, which clashes with this one
gsed -ri "s/\<Sym\>/CompressionSym/g" "$target_swift_src/Compression.swift"

# Comment out the Backtrace.Image conformance (Backtrace is not vendored),
# including the attribute line in front of it
symbol_locator="$target_swift_src/SymbolLocator.swift"
awk '
pending != "" {
    if (/^extension Backtrace\.Image: /) {
        print "/*"
        in_backtrace_image = 1
    }
    print pending
    pending = ""
}
/^@/ && !in_backtrace_image {
    pending = $0
    next
}
in_backtrace_image && /^}$/ {
    print
    print "*/"
    in_backtrace_image = 0
    next
}
{ print }
END { if (pending != "") print pending }
' "$symbol_locator" > "$symbol_locator.tmp" && mv "$symbol_locator.tmp" "$symbol_locator"

# Truncate MemoryReader.swift - remove new platform-specific memory readers
# Keep only up to the end of "extension MemoryReader { ... }"
memory_reader="$target_swift_src/MemoryReader.swift"
awk '
/^extension MemoryReader/ { in_extension = 1 }
in_extension && /^}$/ { print; exit }
{ print }
' "$memory_reader" > "$memory_reader.tmp" && mv "$memory_reader.tmp" "$memory_reader"

echo "Okay, all done."
