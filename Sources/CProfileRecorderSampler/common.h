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

// Scheduler state of a sampled thread, named the same on Linux and Darwin. Linux reads it from
// /proc/self/task/<tid>/stat when the thread list is built (right before signalling in CPU mode); Darwin from the
// mach run_state, just before the thread is suspended.
enum swipr_thread_state {
    swipr_thread_state_unknown = 0,     // not read: never set, or the read failed
    swipr_thread_state_running,         // Linux R, Darwin RUNNING: on a CPU or runnable
    swipr_thread_state_waiting,         // Linux S, Darwin WAITING: interruptible wait (lock, condvar, poll, sleep)
    swipr_thread_state_uninterruptible, // Linux D, Darwin UNINTERRUPTIBLE: uninterruptible kernel wait, usually I/O
    swipr_thread_state_other,           // read, but none of the above: stopped, traced, exiting, kernel-only
};

static inline const char *swipr_thread_state_name(enum swipr_thread_state state) {
    switch (state) {
        case swipr_thread_state_unknown: return "unknown";
        case swipr_thread_state_running: return "running";
        case swipr_thread_state_waiting: return "waiting";
        case swipr_thread_state_uninterruptible: return "uninterruptible";
        case swipr_thread_state_other: return "other";
    }
    return "unknown";
}

#endif /* common_h */
