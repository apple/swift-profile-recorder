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
#pragma once

#include "interface.h"
#include <sys/time.h>

extern struct collector_to_mutators g_swipr_c2ms;
struct swipr_stackframe {
    uintptr_t sf_ip;
    uintptr_t sf_sp;
};

struct swipr_minidump {
    pid_t md_pid;
    swipr_os_dep_thread_id md_tid;

    struct timespec md_time;

    size_t md_stack_depth;
    char md_thread_name[32];
    struct swipr_stackframe md_stack[SWIPR_MAX_STACK_DEPTH];
};

static struct timespec
swipr_sampler_get_current_time(void) {
    struct timeval tv;
    struct timespec ts;
    gettimeofday(&tv, NULL);
    ts.tv_sec = tv.tv_sec + 0;
    ts.tv_nsec = ((typeof(ts.tv_nsec))tv.tv_usec) * SWIPR_NSEC_PER_USEC;
    return ts;
}
