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

#ifndef swipr_os_dep_h
#define swipr_os_dep_h

struct thread_info;

#if __APPLE__ && __has_include(<dispatch/dispatch.h>)
#  include "os_dep_dispatch.h"
#elif __has_include(<pthread.h>)
#  include "os_dep_pthread.h"
#else
#  error "unsupported threading libs"
#endif

#if __linux__
#  include "os_dep_linux.h"
#elif __APPLE__
#  include "os_dep_darwin.h"
#else
#  error "unsupported OS"
#endif
#include "common.h"
#include "sampler.h"
#include "CSampler.h"

struct thread_info *swipr_os_dep_create_thread_list(size_t *all_threads_count, enum swipr_sampling_mode mode);

int swipr_os_dep_destroy_thread_list(struct thread_info *thread_list);

struct swipr_dynamic_lib {
    char dl_name[1024];
    char dl_arch[16];

    /// The slide (always positive), the offset between the in-the-process segment start address and the in-the-file virtual segment start address
    uintptr_t dl_seg_slide;

    /// The in-the-process segment start address (slide + in-the-file virtual segment start address)
    uintptr_t dl_seg_start_addr;

    /// The in-the-process segment end address (slide + in-the-file virtual segment end address)
    uintptr_t dl_seg_end_addr; // dl_seg_start_addr + vmsize
};

int swipr_os_dep_list_all_dynamic_libs(struct swipr_dynamic_lib *all_libs,
                                       size_t all_libs_capacity,
                                       size_t *all_libs_count);

int swipr_os_dep_set_current_thread_name(const char *name);

int swipr_os_dep_get_current_thread_name(char *name, size_t len);

int swipr_os_dep_sample_prepare(size_t num_threads, struct thread_info *all_threads, struct swipr_minidump *minidumps);
void swipr_os_dep_suspend_threads(size_t num_threads, struct thread_info *all_threads);
int swipr_os_dep_sample_cleanup(size_t num_threads, struct thread_info *all_threads);

#endif /* swipr_os_dep_h */
