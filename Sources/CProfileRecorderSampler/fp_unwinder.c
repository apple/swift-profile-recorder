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

void swipr_fp_unwinder_init(struct swipr_fp_unwinder_cursor *cursor, struct swipr_fp_unwinder_context *context) {
    cursor->sfuc_fp = context->sfuctx_fp;
    cursor->sfuc_ip = context->sfuctx_ip;
    cursor->sfuc_original_sp = context->sfuctx_sp;
    cursor->sfuc_frame_depth = 0;
}

int swipr_fp_unwinder_step(struct swipr_fp_unwinder_cursor *cursor) {
    struct swipr_fp_unwinder_cursor old_cursor = *cursor;

    cursor->sfuc_frame_depth++;
    if (cursor->sfuc_frame_depth <= 2) {
        // We return the original IP twice because we're stripping it once in the sample conv.
        return 1; // >0 == continue
    }

    // FIXME: The layout (previous frame followed by return address), stack direction (down) & stack size (128k) are technically arch dependent
    if (
        cursor->sfuc_fp != 0 && // We're not at the end, ...
        cursor->sfuc_fp >= cursor->sfuc_original_sp && // ... we're walking the right direction and ...
        cursor->sfuc_fp - cursor->sfuc_original_sp <= 128*1024 // ... we no more than 128k away from the top of the stack.
    ) {
        uintptr_t *fp = (uintptr_t *)cursor->sfuc_fp;
        cursor->sfuc_fp = fp[0];
        cursor->sfuc_ip = fp[1];
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
#elif defined(__APPLE__) && defined(__x86_64__)
    intptr_t reg_ip = uc->uc_mcontext->__ss.__rip;
    intptr_t reg_fp = uc->uc_mcontext->__ss.__rbp;
    intptr_t reg_sp = uc->uc_mcontext->__ss.__rsp;
#elif defined(__APPLE__) && defined(__aarch64__)
    intptr_t reg_ip = uc->uc_mcontext->__ss.__pc;
    intptr_t reg_fp = uc->uc_mcontext->__ss.__fp;
    intptr_t reg_sp = uc->uc_mcontext->__ss.__sp;
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
