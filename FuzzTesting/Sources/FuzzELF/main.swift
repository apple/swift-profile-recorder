//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import _ProfileRecorderSampleConversion

@_cdecl("LLVMFuzzerTestOneInput")
public func fuzzELF(_ start: UnsafeRawPointer, _ count: Int) -> CInt {
    let buffer = UnsafeRawBufferPointer(start: start, count: count)
    let source = ImageSource(unowned: buffer, isMappedImage: false)

    if let image = try? Elf32Image(source: source) {
        exerciseElfImage(image)
    }
    if let image = try? Elf64Image(source: source) {
        exerciseElfImage(image)
    }

    return 0
}

private func exerciseElfImage<Traits: ElfTraits>(_ image: ElfImage<Traits>) {
    _ = image.uuid
    _ = image.debugLinkCRC
    _ = image.ehFrameInfo
    _ = image.imageName
    _ = image.getSection(".text")
    _ = image.getSection(".symtab")
    _ = image.getSection(".strtab")
    _ = image.getSection(".debug_info")
    _ = image.getSection(".debug_line")
    _ = image.getDebugLink()
    _ = image.getDebugAltLink()
    _ = image.getSectionAsString(".comment")
    for _ in image.notes {}

    // Symbol table: construction and merge
    if let symtab = ElfSymbolTable(image: image) {
        if let symtab2 = ElfSymbolTable(image: image) {
            _ = symtab.merged(with: symtab2)
        }
    }

    // Collect addresses from the fuzzed image's own headers to exercise lookup
    // paths with values that actually fall within the image's address ranges.
    var addresses: [UInt64] = [0]
    for phdr in image.programHeaders where phdr.p_type == .internal_SWIPR_PT_LOAD {
        let vaddr = UInt64(phdr.p_vaddr)
        addresses.append(vaddr)
        addresses.append(vaddr &+ UInt64(phdr.p_memsz) / 2)
    }
    if let sections = image.sectionHeaders {
        for shdr in sections where shdr.sh_addr != 0 {
            addresses.append(UInt64(shdr.sh_addr))
        }
    }

    let symtab = ElfSymbolTable(image: image)
    for addr in addresses {
        _ = symtab?.lookupSymbol(address: Traits.Address(truncatingIfNeeded: addr))
        _ = image.lookupSymbol(address: Traits.Address(truncatingIfNeeded: addr))
        _ = try? image.sourceLocation(for: Traits.Address(truncatingIfNeeded: addr))
        _ = image.inlineCallSites(at: Traits.Address(truncatingIfNeeded: addr))
    }

    // DWARF section access
    _ = image.getDwarfSection(.debugInfo)
    _ = image.getDwarfSection(.debugLine)
    _ = image.getDwarfSection(.debugAbbrev)
    _ = image.getDwarfSection(.debugStr)
    _ = image.getDwarfSection(.debugRanges)
    _ = image.getDwarfSection(.debugRngLists)
    _ = image.getDwarfSection(.debugAddr)
    _ = image.getDwarfSection(.debugStrOffsets)
    _ = image.getDwarfSection(.debugLineStr)
}
