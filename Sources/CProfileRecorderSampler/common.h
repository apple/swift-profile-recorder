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


#ifndef common_h
#define common_h

#include <string.h>
#include <stdio.h>
#include <unistd.h>

#define SWIPR_MAX_MUTATOR_THREADS 1024
#define SWIPR_MAX_STACK_DEPTH 128
#define SWIPR_MAX_LIBS 16384

#define SWIPR_NSEC_PER_USEC 1000ULL
#define SWIPR_NSEC_PER_MSEC (1000ULL * SWIPR_NSEC_PER_USEC)
#define SWIPR_NSEC_PER_SEC (1000ULL * SWIPR_NSEC_PER_MSEC)

#if defined(SWIPR_ENABLE_UNSAFE_DEBUG)
#  define UNSAFE_DEBUG(...) \
    do { \
        char buffer[512] = {0}; \
        snprintf(buffer, sizeof(buffer), "ProfileRecorder: " __VA_ARGS__); \
        write(STDERR_FILENO, buffer, strlen(buffer)); \
    } while (0)
#else
#  define UNSAFE_DEBUG(...) do { } while (0)
#endif

#define SWIPR_MIN(a, b) ((a) < (b) ? (a) : (b))

// Scheduler state of a sampled thread. Linux reports the proc(5) states, read
// when the thread list is built (right before signalling in CPU mode); Darwin
// the mach run_state ones, read just before the thread is suspended.
enum swipr_thread_state {
    swipr_thread_state_unknown = 0,
    swipr_thread_state_running,
    swipr_thread_state_sleeping,
    swipr_thread_state_disk_sleep,
    swipr_thread_state_stopped,
    swipr_thread_state_tracing_stop,
    swipr_thread_state_zombie,
    swipr_thread_state_dead,
    swipr_thread_state_parked,
    swipr_thread_state_idle,
    swipr_thread_state_waiting,
    swipr_thread_state_uninterruptible,
    swipr_thread_state_halted,
};

// NULL for swipr_thread_state_unknown, so an unknown state is left out of
// the output rather than reported.
static inline const char *swipr_thread_state_name(enum swipr_thread_state state) {
    switch (state) {
        case swipr_thread_state_unknown: return NULL;
        case swipr_thread_state_running: return "running";
        case swipr_thread_state_sleeping: return "sleeping";
        case swipr_thread_state_disk_sleep: return "disk-sleep";
        case swipr_thread_state_stopped: return "stopped";
        case swipr_thread_state_tracing_stop: return "tracing-stop";
        case swipr_thread_state_zombie: return "zombie";
        case swipr_thread_state_dead: return "dead";
        case swipr_thread_state_parked: return "parked";
        case swipr_thread_state_idle: return "idle";
        case swipr_thread_state_waiting: return "waiting";
        case swipr_thread_state_uninterruptible: return "uninterruptible";
        case swipr_thread_state_halted: return "halted";
    }
    return NULL;
}

#endif /* common_h */
