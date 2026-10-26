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

#ifndef FP_UNWINDER_H
#define FP_UNWINDER_H

#define _GNU_SOURCE
#include <signal.h>
#include <stdint.h>

// Holds a whole page, so one copy per stack page. Linux page size is a kernel build option; 64k is the largest.
#if defined(__APPLE__)
#include <mach/vm_param.h>
#define SWIPR_FP_UNWINDER_COPY_SIZE PAGE_MAX_SIZE
#else
#define SWIPR_FP_UNWINDER_COPY_SIZE 65536
#endif

struct swipr_fp_unwinder_cursor {
    intptr_t sfuc_fp;
    intptr_t sfuc_ip;
    intptr_t sfuc_original_sp;
    int sfuc_frame_depth;
    // [sfuc_copy_start, sfuc_copy_end) of the stack, copied through swipr_os_dep_copy_memory.
    uintptr_t sfuc_copy_start;
    uintptr_t sfuc_copy_end;
    uintptr_t sfuc_copy[SWIPR_FP_UNWINDER_COPY_SIZE / sizeof(uintptr_t)];
};

struct swipr_fp_unwinder_context {
    intptr_t sfuctx_ip;
    intptr_t sfuctx_fp;
    intptr_t sfuctx_sp;
};

enum swipr_fp_unwinder_register {
    SWIPR_FP_UNWINDER_REG_IP = 1111,
    SWIPR_FP_UNWINDER_REG_FP = 2222
};

void swipr_fp_unwinder_init(struct swipr_fp_unwinder_cursor *cursor, struct swipr_fp_unwinder_context *context);

int swipr_fp_unwinder_step(struct swipr_fp_unwinder_cursor *cursor);

int swipr_fp_unwinder_get_reg(struct swipr_fp_unwinder_cursor *cursor, enum swipr_fp_unwinder_register reg, uintptr_t *output);

int swipr_fp_unwinder_getcontext(struct swipr_fp_unwinder_context *context, ucontext_t *uc);

#endif
