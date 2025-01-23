//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2022-2025 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//
//  Implements swipr_unw_* functions from <libunwind.h>
//
//===----------------------------------------------------------------------===//

#include <libunwind.h>

#include "config.h"
#include "libunwind_ext.h"

#include <stdlib.h>

// Define the __has_feature extension for compilers that do not support it so
// that we can later check for the presence of ASan in a compiler-neutral way.
#if !defined(__has_feature)
#define __has_feature(feature) 0
#endif

#if __has_feature(address_sanitizer) || defined(__SANITIZE_ADDRESS__)
#include <sanitizer/asan_interface.h>
#endif

#if !defined(__USING_SJLJ_EXCEPTIONS__) && !defined(__wasm__)
#include "AddressSpace.hpp"
#include "UnwindCursor.hpp"

using namespace libunwind;

#if __APPLE__ || __GLIBC__
/// internal object to represent this processes address space
LocalAddressSpace LocalAddressSpace::sThisAddressSpace;
#endif

_LIBUNWIND_EXPORT swipr_unw_addr_space_t swipr_unw_local_addr_space =
    (swipr_unw_addr_space_t)&LocalAddressSpace::sThisAddressSpace;

/// Create a cursor of a thread in this process given 'context' recorded by
/// __swipr_unw_getcontext().
_LIBUNWIND_HIDDEN int __swipr_unw_init_local(swipr_unw_cursor_t *cursor,
                                       swipr_unw_context_t *context) {
  _LIBUNWIND_TRACE_API("__swipr_unw_init_local(cursor=%p, context=%p)",
                       static_cast<void *>(cursor),
                       static_cast<void *>(context));
#if defined(__i386__)
# define REGISTER_KIND Registers_x86
#elif defined(__x86_64__)
# define REGISTER_KIND Registers_x86_64
#elif defined(__powerpc64__)
# define REGISTER_KIND Registers_ppc64
#elif defined(__powerpc__)
# define REGISTER_KIND Registers_ppc
#elif defined(__aarch64__)
# define REGISTER_KIND Registers_arm64
#elif defined(__arm__)
# define REGISTER_KIND Registers_arm
#elif defined(__or1k__)
# define REGISTER_KIND Registers_or1k
#elif defined(__hexagon__)
# define REGISTER_KIND Registers_hexagon
#elif defined(__mips__) && defined(_ABIO32) && _MIPS_SIM == _ABIO32
# define REGISTER_KIND Registers_mips_o32
#elif defined(__mips64)
# define REGISTER_KIND Registers_mips_newabi
#elif defined(__mips__)
# warning The MIPS architecture is not supported with this ABI and environment!
#elif defined(__sparc__) && defined(__arch64__)
#define REGISTER_KIND Registers_sparc64
#elif defined(__sparc__)
# define REGISTER_KIND Registers_sparc
#elif defined(__riscv)
# define REGISTER_KIND Registers_riscv
#elif defined(__ve__)
# define REGISTER_KIND Registers_ve
#elif defined(__s390x__)
# define REGISTER_KIND Registers_s390x
#elif defined(__loongarch__) && __loongarch_grlen == 64
#define REGISTER_KIND Registers_loongarch
#else
# error Architecture not supported
#endif
  // Use "placement new" to allocate UnwindCursor in the cursor buffer.
  new (reinterpret_cast<UnwindCursor<LocalAddressSpace, REGISTER_KIND> *>(cursor))
      UnwindCursor<LocalAddressSpace, REGISTER_KIND>(
          context, LocalAddressSpace::sThisAddressSpace);
#undef REGISTER_KIND
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  co->setInfoBasedOnIPRegister();

  return UNW_ESUCCESS;
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_init_local, swipr_unw_init_local)

/// Get value of specified register at cursor position in stack frame.
_LIBUNWIND_HIDDEN int __swipr_unw_get_reg(swipr_unw_cursor_t *cursor, swipr_unw_regnum_t regNum,
                                    swipr_unw_word_t *value) {
  _LIBUNWIND_TRACE_API("__swipr_unw_get_reg(cursor=%p, regNum=%d, &value=%p)",
                       static_cast<void *>(cursor), regNum,
                       static_cast<void *>(value));
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  if (co->validReg(regNum)) {
    *value = co->getReg(regNum);
    return UNW_ESUCCESS;
  }
  return UNW_EBADREG;
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_get_reg, swipr_unw_get_reg)

/// Set value of specified register at cursor position in stack frame.
_LIBUNWIND_HIDDEN int __swipr_unw_set_reg(swipr_unw_cursor_t *cursor, swipr_unw_regnum_t regNum,
                                    swipr_unw_word_t value) {
  _LIBUNWIND_TRACE_API("__swipr_unw_set_reg(cursor=%p, regNum=%d, value=0x%" PRIxPTR
                       ")",
                       static_cast<void *>(cursor), regNum, value);
  typedef LocalAddressSpace::pint_t pint_t;
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  if (co->validReg(regNum)) {
    co->setReg(regNum, (pint_t)value);
    // special case altering IP to re-find info (being called by personality
    // function)
    if (regNum == UNW_REG_IP) {
      swipr_unw_proc_info_t info;
      // First, get the FDE for the old location and then update it.
      co->getInfo(&info);
      co->setInfoBasedOnIPRegister(false);
      // If the original call expects stack adjustment, perform this now.
      // Normal frame unwinding would have included the offset already in the
      // CFA computation.
      // Note: for PA-RISC and other platforms where the stack grows up,
      // this should actually be - info.gp. LLVM doesn't currently support
      // any such platforms and Clang doesn't export a macro for them.
      if (info.gp)
        co->setReg(UNW_REG_SP, co->getReg(UNW_REG_SP) + info.gp);
    }
    return UNW_ESUCCESS;
  }
  return UNW_EBADREG;
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_set_reg, swipr_unw_set_reg)

/// Get value of specified float register at cursor position in stack frame.
_LIBUNWIND_HIDDEN int __swipr_unw_get_fpreg(swipr_unw_cursor_t *cursor, swipr_unw_regnum_t regNum,
                                      swipr_unw_fpreg_t *value) {
  _LIBUNWIND_TRACE_API("__swipr_unw_get_fpreg(cursor=%p, regNum=%d, &value=%p)",
                       static_cast<void *>(cursor), regNum,
                       static_cast<void *>(value));
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  if (co->validFloatReg(regNum)) {
    *value = co->getFloatReg(regNum);
    return UNW_ESUCCESS;
  }
  return UNW_EBADREG;
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_get_fpreg, swipr_unw_get_fpreg)

/// Set value of specified float register at cursor position in stack frame.
_LIBUNWIND_HIDDEN int __swipr_unw_set_fpreg(swipr_unw_cursor_t *cursor, swipr_unw_regnum_t regNum,
                                      swipr_unw_fpreg_t value) {
#if defined(_LIBUNWIND_ARM_EHABI)
  _LIBUNWIND_TRACE_API("__swipr_unw_set_fpreg(cursor=%p, regNum=%d, value=%llX)",
                       static_cast<void *>(cursor), regNum, value);
#else
  _LIBUNWIND_TRACE_API("__swipr_unw_set_fpreg(cursor=%p, regNum=%d, value=%g)",
                       static_cast<void *>(cursor), regNum, value);
#endif
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  if (co->validFloatReg(regNum)) {
    co->setFloatReg(regNum, value);
    return UNW_ESUCCESS;
  }
  return UNW_EBADREG;
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_set_fpreg, swipr_unw_set_fpreg)

/// Move cursor to next frame.
_LIBUNWIND_HIDDEN int __swipr_unw_step(swipr_unw_cursor_t *cursor) {
  _LIBUNWIND_TRACE_API("__swipr_unw_step(cursor=%p)", static_cast<void *>(cursor));
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  return co->step();
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_step, swipr_unw_step)

// Move cursor to next frame and for stage2 of unwinding.
// This resets MTE tags of tagged frames to zero.
extern "C" _LIBUNWIND_HIDDEN int __swipr_unw_step_stage2(swipr_unw_cursor_t *cursor) {
  _LIBUNWIND_TRACE_API("__swipr_unw_step_stage2(cursor=%p)",
                       static_cast<void *>(cursor));
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  return co->step(true);
}

/// Get unwind info at cursor position in stack frame.
_LIBUNWIND_HIDDEN int __swipr_unw_get_proc_info(swipr_unw_cursor_t *cursor,
                                          swipr_unw_proc_info_t *info) {
  _LIBUNWIND_TRACE_API("__swipr_unw_get_proc_info(cursor=%p, &info=%p)",
                       static_cast<void *>(cursor), static_cast<void *>(info));
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  co->getInfo(info);
  if (info->end_ip == 0)
    return UNW_ENOINFO;
  return UNW_ESUCCESS;
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_get_proc_info, swipr_unw_get_proc_info)

/// Resume execution at cursor position (aka longjump).
_LIBUNWIND_HIDDEN int __swipr_unw_resume(swipr_unw_cursor_t *cursor) {
  _LIBUNWIND_TRACE_API("__swipr_unw_resume(cursor=%p)", static_cast<void *>(cursor));
#if __has_feature(address_sanitizer) || defined(__SANITIZE_ADDRESS__)
  // Inform the ASan runtime that now might be a good time to clean stuff up.
  __asan_handle_no_return();
#endif
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  co->jumpto();
  return UNW_EUNSPEC;
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_resume, swipr_unw_resume)

/// Get name of function at cursor position in stack frame.
_LIBUNWIND_HIDDEN int __swipr_unw_get_proc_name(swipr_unw_cursor_t *cursor, char *buf,
                                          size_t bufLen, swipr_unw_word_t *offset) {
  _LIBUNWIND_TRACE_API("__swipr_unw_get_proc_name(cursor=%p, &buf=%p, bufLen=%lu)",
                       static_cast<void *>(cursor), static_cast<void *>(buf),
                       static_cast<unsigned long>(bufLen));
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  if (co->getFunctionName(buf, bufLen, offset))
    return UNW_ESUCCESS;
  return UNW_EUNSPEC;
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_get_proc_name, swipr_unw_get_proc_name)

/// Checks if a register is a floating-point register.
_LIBUNWIND_HIDDEN int __swipr_unw_is_fpreg(swipr_unw_cursor_t *cursor,
                                     swipr_unw_regnum_t regNum) {
  _LIBUNWIND_TRACE_API("__swipr_unw_is_fpreg(cursor=%p, regNum=%d)",
                       static_cast<void *>(cursor), regNum);
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  return co->validFloatReg(regNum);
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_is_fpreg, swipr_unw_is_fpreg)

/// Checks if a register is a floating-point register.
_LIBUNWIND_HIDDEN const char *__swipr_unw_regname(swipr_unw_cursor_t *cursor,
                                            swipr_unw_regnum_t regNum) {
  _LIBUNWIND_TRACE_API("__swipr_unw_regname(cursor=%p, regNum=%d)",
                       static_cast<void *>(cursor), regNum);
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  return co->getRegisterName(regNum);
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_regname, swipr_unw_regname)

/// Checks if current frame is signal trampoline.
_LIBUNWIND_HIDDEN int __swipr_unw_is_signal_frame(swipr_unw_cursor_t *cursor) {
  _LIBUNWIND_TRACE_API("__swipr_unw_is_signal_frame(cursor=%p)",
                       static_cast<void *>(cursor));
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  return co->isSignalFrame();
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_is_signal_frame, swipr_unw_is_signal_frame)

#ifdef _AIX
_LIBUNWIND_EXPORT uintptr_t __swipr_unw_get_data_rel_base(swipr_unw_cursor_t *cursor) {
  _LIBUNWIND_TRACE_API("swipr_unw_get_data_rel_base(cursor=%p)",
                       static_cast<void *>(cursor));
  AbstractUnwindCursor *co = reinterpret_cast<AbstractUnwindCursor *>(cursor);
  return co->getDataRelBase();
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_get_data_rel_base, swipr_unw_get_data_rel_base)
#endif

#ifdef __arm__
// Save VFP registers d0-d15 using FSTMIADX instead of FSTMIADD
_LIBUNWIND_HIDDEN void __swipr_unw_save_vfp_as_X(swipr_unw_cursor_t *cursor) {
  _LIBUNWIND_TRACE_API("__swipr_unw_get_fpreg_save_vfp_as_X(cursor=%p)",
                       static_cast<void *>(cursor));
  AbstractUnwindCursor *co = (AbstractUnwindCursor *)cursor;
  return co->saveVFPAsX();
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_save_vfp_as_X, swipr_unw_save_vfp_as_X)
#endif


#if defined(_LIBUNWIND_SUPPORT_DWARF_UNWIND)
/// SPI: walks cached DWARF entries
_LIBUNWIND_HIDDEN void __swipr_unw_iterate_dwarf_unwind_cache(void (*func)(
    swipr_unw_word_t ip_start, swipr_unw_word_t ip_end, swipr_unw_word_t fde, swipr_unw_word_t mh)) {
  _LIBUNWIND_TRACE_API("__swipr_unw_iterate_dwarf_unwind_cache(func=%p)",
                       reinterpret_cast<void *>(func));
  DwarfFDECache<LocalAddressSpace>::iterateCacheEntries(func);
}
_LIBUNWIND_WEAK_ALIAS(__swipr_unw_iterate_dwarf_unwind_cache,
                      swipr_unw_iterate_dwarf_unwind_cache)

/// IPI: for __swipr_register_frame()
void __swipr_unw_add_dynamic_fde(swipr_unw_word_t fde) {
  CFI_Parser<LocalAddressSpace>::FDE_Info fdeInfo;
  CFI_Parser<LocalAddressSpace>::CIE_Info cieInfo;
  const char *message = CFI_Parser<LocalAddressSpace>::decodeFDE(
                           LocalAddressSpace::sThisAddressSpace,
                          (LocalAddressSpace::pint_t) fde, &fdeInfo, &cieInfo);
  if (message == NULL) {
    // dynamically registered FDEs don't have a mach_header group they are in.
    // Use fde as mh_group
    swipr_unw_word_t mh_group = fdeInfo.fdeStart;
    DwarfFDECache<LocalAddressSpace>::add((LocalAddressSpace::pint_t)mh_group,
                                          fdeInfo.pcStart, fdeInfo.pcEnd,
                                          fdeInfo.fdeStart);
  } else {
    _LIBUNWIND_DEBUG_LOG("__swipr_unw_add_dynamic_fde: bad fde: %s", message);
  }
}

/// IPI: for __swipr_deregister_frame()
void __swipr_unw_remove_dynamic_fde(swipr_unw_word_t fde) {
  // fde is own mh_group
  DwarfFDECache<LocalAddressSpace>::removeAllIn((LocalAddressSpace::pint_t)fde);
}

void __swipr_unw_add_dynamic_eh_frame_section(swipr_unw_word_t eh_frame_start) {
  // The eh_frame section start serves as the mh_group
  swipr_unw_word_t mh_group = eh_frame_start;
  CFI_Parser<LocalAddressSpace>::CIE_Info cieInfo;
  CFI_Parser<LocalAddressSpace>::FDE_Info fdeInfo;
  auto p = (LocalAddressSpace::pint_t)eh_frame_start;
  while (LocalAddressSpace::sThisAddressSpace.get32(p)) {
    if (CFI_Parser<LocalAddressSpace>::decodeFDE(
            LocalAddressSpace::sThisAddressSpace, p, &fdeInfo, &cieInfo,
            true) == NULL) {
      DwarfFDECache<LocalAddressSpace>::add((LocalAddressSpace::pint_t)mh_group,
                                            fdeInfo.pcStart, fdeInfo.pcEnd,
                                            fdeInfo.fdeStart);
      p += fdeInfo.fdeLength;
    } else if (CFI_Parser<LocalAddressSpace>::parseCIE(
                   LocalAddressSpace::sThisAddressSpace, p, &cieInfo) == NULL) {
      p += cieInfo.cieLength;
    } else
      return;
  }
}

void __swipr_unw_remove_dynamic_eh_frame_section(swipr_unw_word_t eh_frame_start) {
  // The eh_frame section start serves as the mh_group
  DwarfFDECache<LocalAddressSpace>::removeAllIn(
      (LocalAddressSpace::pint_t)eh_frame_start);
}

#endif // defined(_LIBUNWIND_SUPPORT_DWARF_UNWIND)
#endif // !defined(__USING_SJLJ_EXCEPTIONS__) && !defined(__wasm__)

#ifdef __APPLE__

namespace libunwind {

static constexpr size_t MAX_DYNAMIC_UNWIND_SECTIONS_FINDERS = 8;

static RWMutex findDynamicUnwindSectionsLock;
static size_t numDynamicUnwindSectionsFinders = 0;
static swipr_unw_find_dynamic_unwind_sections
    dynamicUnwindSectionsFinders[MAX_DYNAMIC_UNWIND_SECTIONS_FINDERS] = {0};

bool findDynamicUnwindSections(void *addr, swipr_unw_dynamic_unwind_sections *info) {
  bool found = false;
  findDynamicUnwindSectionsLock.lock_shared();
  for (size_t i = 0; i != numDynamicUnwindSectionsFinders; ++i) {
    if (dynamicUnwindSectionsFinders[i]((swipr_unw_word_t)addr, info)) {
      found = true;
      break;
    }
  }
  findDynamicUnwindSectionsLock.unlock_shared();
  return found;
}

} // namespace libunwind

int __swipr_unw_add_find_dynamic_unwind_sections(
    swipr_unw_find_dynamic_unwind_sections find_dynamic_unwind_sections) {
  findDynamicUnwindSectionsLock.lock();

  // Check that we have enough space...
  if (numDynamicUnwindSectionsFinders == MAX_DYNAMIC_UNWIND_SECTIONS_FINDERS) {
    findDynamicUnwindSectionsLock.unlock();
    return UNW_ENOMEM;
  }

  // Check for value already present...
  for (size_t i = 0; i != numDynamicUnwindSectionsFinders; ++i) {
    if (dynamicUnwindSectionsFinders[i] == find_dynamic_unwind_sections) {
      findDynamicUnwindSectionsLock.unlock();
      return UNW_EINVAL;
    }
  }

  // Success -- add callback entry.
  dynamicUnwindSectionsFinders[numDynamicUnwindSectionsFinders++] =
    find_dynamic_unwind_sections;
  findDynamicUnwindSectionsLock.unlock();

  return UNW_ESUCCESS;
}

int __swipr_unw_remove_find_dynamic_unwind_sections(
    swipr_unw_find_dynamic_unwind_sections find_dynamic_unwind_sections) {
  findDynamicUnwindSectionsLock.lock();

  // Find index to remove.
  size_t finderIdx = numDynamicUnwindSectionsFinders;
  for (size_t i = 0; i != numDynamicUnwindSectionsFinders; ++i) {
    if (dynamicUnwindSectionsFinders[i] == find_dynamic_unwind_sections) {
      finderIdx = i;
      break;
    }
  }

  // If no such registration is present then error out.
  if (finderIdx == numDynamicUnwindSectionsFinders) {
    findDynamicUnwindSectionsLock.unlock();
    return UNW_EINVAL;
  }

  // Remove entry.
  for (size_t i = finderIdx; i != numDynamicUnwindSectionsFinders - 1; ++i)
    dynamicUnwindSectionsFinders[i] = dynamicUnwindSectionsFinders[i + 1];
  dynamicUnwindSectionsFinders[--numDynamicUnwindSectionsFinders] = nullptr;

  findDynamicUnwindSectionsLock.unlock();
  return UNW_ESUCCESS;
}

#endif // __APPLE__

// Add logging hooks in Debug builds only
#ifndef NDEBUG
#if __APPLE__ || __GLIBC__
#include <stdlib.h>

_LIBUNWIND_HIDDEN
bool logAPIs() {
  // do manual lock to avoid use of _cxa_guard_acquire or initializers
  static bool checked = false;
  static bool log = false;
  if (!checked) {
    log = (getenv("LIBUNWIND_PRINT_APIS") != NULL);
    checked = true;
  }
  return log;
}

_LIBUNWIND_HIDDEN
bool logUnwinding() {
  // do manual lock to avoid use of _cxa_guard_acquire or initializers
  static bool checked = false;
  static bool log = false;
  if (!checked) {
    log = (getenv("LIBUNWIND_PRINT_UNWINDING") != NULL);
    checked = true;
  }
  return log;
}

_LIBUNWIND_HIDDEN
bool logDWARF() {
  // do manual lock to avoid use of _cxa_guard_acquire or initializers
  static bool checked = false;
  static bool log = false;
  if (!checked) {
    log = (getenv("LIBUNWIND_PRINT_DWARF") != NULL);
    checked = true;
  }
  return log;
}

#endif // __APPLE__ || __GLIBC__
#endif // NDEBUG

