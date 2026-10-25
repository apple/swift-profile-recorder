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

#include <stdbool.h>
#include "fp_unwinder.h"
#include "common.h"
#include "os_dep.h"

void swipr_fp_unwinder_init(struct swipr_fp_unwinder_cursor *cursor, struct swipr_fp_unwinder_context *context) {
    cursor->sfuc_fp = context->sfuctx_fp;
    cursor->sfuc_ip = context->sfuctx_ip;
    cursor->sfuc_original_sp = context->sfuctx_sp;
    cursor->sfuc_frame_depth = 0;
    cursor->sfuc_copy_start = 0;
    cursor->sfuc_copy_end = 0;
}

static bool swipr_fp_unwinder_read_frame_record(struct swipr_fp_unwinder_cursor *cursor, uintptr_t fp,
                                                uintptr_t record[2]) {
    if (fp < cursor->sfuc_copy_start || fp + 2 * sizeof(uintptr_t) > cursor->sfuc_copy_end) {
        uintptr_t page_size = (uintptr_t)getpagesize();
        uintptr_t end = (fp & ~(page_size - 1)) + page_size;
        if (end - fp < 2 * sizeof(uintptr_t)) {
            end = fp + 2 * sizeof(uintptr_t);
        }
        if (end - fp > sizeof(cursor->sfuc_copy)) {
            end = fp + sizeof(cursor->sfuc_copy);
        }
        if (!swipr_os_dep_copy_memory(cursor->sfuc_copy, fp, end - fp)) {
            return false;
        }
        cursor->sfuc_copy_start = fp;
        cursor->sfuc_copy_end = end;
    }
    const uintptr_t *words = &cursor->sfuc_copy[(fp - cursor->sfuc_copy_start) / sizeof(uintptr_t)];
    record[0] = words[0];
    record[1] = words[1];
    return true;
}

int swipr_fp_unwinder_step(struct swipr_fp_unwinder_cursor *cursor) {
    cursor->sfuc_frame_depth++;
    if (cursor->sfuc_frame_depth <= 2) {
        // We return the original IP twice because we're stripping it once in the sample conv.
        return 1; // >0 == continue
    }

    // FIXME: The layout (previous frame followed by return address), stack direction (down) & stack size (128k) are technically arch dependent
    if (
        cursor->sfuc_fp != 0 && // We're not at the end, ...
        cursor->sfuc_fp % sizeof(uintptr_t) == 0 && // ... the frame record is word aligned, ...
        cursor->sfuc_fp >= cursor->sfuc_original_sp && // ... we're walking the right direction and ...
        cursor->sfuc_fp - cursor->sfuc_original_sp <= 128*1024 // ... we no more than 128k away from the top of the stack.
    ) {
        uintptr_t record[2];
        if (!swipr_fp_unwinder_read_frame_record(cursor, cursor->sfuc_fp, record)) {
            return 0;
        }
        cursor->sfuc_fp = record[0];
        cursor->sfuc_ip = record[1];
        return 1; // >0 == continue
    } else {
            UNSAFE_DEBUG("ending stack unwind (fp!=0: %d, fp>sp: %d, fp-sp: %ld)",
                         cursor->sfuc_fp != 0,
                         cursor->sfuc_fp >= cursor->sfuc_original_sp,
                         cursor->sfuc_fp - cursor->sfuc_original_sp);
        return 0; // 0 == stop
    }
}

int swipr_fp_unwinder_get_reg(struct swipr_fp_unwinder_cursor *cursor,
                              enum swipr_fp_unwinder_register reg,
                              uintptr_t *output) {
    switch (reg) {
    case SWIPR_FP_UNWINDER_REG_IP:
        *output = cursor->sfuc_ip;
        break;
    case SWIPR_FP_UNWINDER_REG_FP:
        *output = cursor->sfuc_fp;
        break;
    default:
        return 1;
    }
    return 0;
}

int swipr_fp_unwinder_getcontext(struct swipr_fp_unwinder_context *context, ucontext_t *uc) {
#if defined(__linux__) && defined(__x86_64__)
    intptr_t reg_ip = uc->uc_mcontext.gregs[REG_RIP];
    intptr_t reg_fp = uc->uc_mcontext.gregs[REG_RBP];
    intptr_t reg_sp = uc->uc_mcontext.gregs[REG_RSP];
#elif defined(__linux__) && defined(__aarch64__)
    intptr_t reg_ip = uc->uc_mcontext.pc;
    intptr_t reg_fp = uc->uc_mcontext.regs[29];
    intptr_t reg_sp = uc->uc_mcontext.sp;
#elif defined(__linux__) && defined(__arm__)
    // ARM (32-bit) on Linux (e.g. ARMv6 and ARMv7)
    intptr_t reg_ip = uc->uc_mcontext.arm_pc;
    intptr_t reg_fp = uc->uc_mcontext.arm_fp;  // r11 is the frame pointer
    intptr_t reg_sp = uc->uc_mcontext.arm_sp;  // r13 is the stack pointer
#elif defined(__APPLE__) && defined(__x86_64__)
    intptr_t reg_ip = uc->uc_mcontext->__ss.__rip;
    intptr_t reg_fp = uc->uc_mcontext->__ss.__rbp;
    intptr_t reg_sp = uc->uc_mcontext->__ss.__rsp;
#elif defined(__APPLE__) && defined(__aarch64__)
    intptr_t reg_ip = __darwin_arm_thread_state64_get_pc(uc->uc_mcontext->__ss);
    intptr_t reg_fp = __darwin_arm_thread_state64_get_fp(uc->uc_mcontext->__ss);
    intptr_t reg_sp = __darwin_arm_thread_state64_get_sp(uc->uc_mcontext->__ss);
#else
#warning unknown OS/arch combination
    intptr_t reg_ip = 0;
    intptr_t reg_fp = 0;
    intptr_t reg_sp = 0;
#endif

    context->sfuctx_fp = reg_fp;
    context->sfuctx_ip = reg_ip;
    context->sfuctx_sp = reg_sp;

    return 0;
}
