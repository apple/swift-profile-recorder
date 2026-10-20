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

#if __APPLE__

#include <pthread.h>
#include <mach/thread_info.h>
#include <mach/machine/thread_status.h>
#include <mach-o/dyld.h>
#include <mach/mach_vm.h>
#include <string.h>
#include <stdio.h>

#include "os_dep.h"
#include "asserts.h"

struct thread_info *swipr_os_dep_create_thread_list(size_t *all_threads_count, enum swipr_sampling_mode mode) {
    // Allocated first: task_threads hands out a port right per thread, which a later failure would leak.
    struct thread_info *all_threads = calloc(SWIPR_MAX_MUTATOR_THREADS, sizeof(struct thread_info));
    if (!all_threads) {
        *all_threads_count = 0;
        return NULL;
    }
    thread_array_t threads = NULL;
    mach_msg_type_number_t threads_count = 0;
    kern_return_t kret = task_threads(mach_task_self(),
                                     &threads,
                                     &threads_count);
    if (kret) {
        free(all_threads);
        *all_threads_count = 0;
        return NULL;
    }
    memset(all_threads, 0, sizeof(*all_threads) * SWIPR_MAX_MUTATOR_THREADS);

    // mach_thread_self returns a new send right, so take it once and release it below.
    thread_t controller = mach_thread_self();
    size_t next_index = 0;
    for (mach_msg_type_number_t i = 0; i < threads_count; i++) {
        thread_t thread = threads[i];
        // O(1) kernel lookups; pthread_from_mach_thread_np and pthread_getname_np walk all threads, O(n) each.
        thread_extended_info_data_t ext_info;
        mach_msg_type_number_t ext_count = THREAD_EXTENDED_INFO_COUNT;
        thread_identifier_info_data_t tid_info;
        mach_msg_type_number_t tid_count = THREAD_IDENTIFIER_INFO_COUNT;
        bool keep = thread != controller
            && next_index < SWIPR_MAX_MUTATOR_THREADS
            && thread_info(thread, THREAD_EXTENDED_INFO, (thread_info_t)&ext_info, &ext_count) == KERN_SUCCESS
            // Must be read before thread_suspend, which makes every thread report TH_STATE_WAITING.
            && (mode != SWIPR_SAMPLING_CPU || ext_info.pth_run_state == TH_STATE_RUNNING)
            && thread_info(thread, THREAD_IDENTIFIER_INFO, (thread_info_t)&tid_info, &tid_count) == KERN_SUCCESS
            && tid_info.thread_handle != 0; // mach threads without a pthread
        if (!keep) {
            kret = mach_port_deallocate(mach_task_self(), thread);
            swipr_precondition(kret == KERN_SUCCESS);
            continue;
        }

        struct thread_info *info = &all_threads[next_index++];
        info->ti_id = tid_info.thread_id;
        info->ti_os_specific.mach_thread = thread;
        if (ext_info.pth_name[0] == 0) {
            strcpy(info->ti_name, "<n/a>"); // threads may have empty names
        } else {
            strlcpy(info->ti_name, ext_info.pth_name, sizeof(info->ti_name));
        }
    }
    kret = mach_port_deallocate(mach_task_self(), controller);
    swipr_precondition(kret == KERN_SUCCESS);
    kret = vm_deallocate(mach_task_self(),
                         (vm_address_t)threads,
                         threads_count * sizeof(thread_t));
    swipr_precondition(kret == KERN_SUCCESS);
    *all_threads_count = next_index;
    return all_threads;
}

int swipr_os_dep_destroy_thread_list(struct thread_info *thread_list) {
    swipr_precondition(thread_list);
    int err = 0;
    for (int i = 0; i < SWIPR_MAX_MUTATOR_THREADS; i++) {
        if (thread_list[i].ti_os_specific.mach_thread == THREAD_NULL) {
            // wasn't allocated a port right
            continue;
        } else {
            kern_return_t kret = mach_port_deallocate(mach_task_self(), thread_list[i].ti_os_specific.mach_thread);
            swipr_precondition(kret == KERN_SUCCESS);
        }
    }
    free(thread_list);
    return err;
}

int swipr_os_dep_list_all_dynamic_libs(struct swipr_dynamic_lib *all_libs,
                                       size_t all_libs_capacity,
                                       size_t *all_libs_count) {
    int img_count = _dyld_image_count();
    int libs_count = 0;
    uint arch_size = sizeof(all_libs[0].dl_arch);
    for (int image_index = 0; image_index < img_count; image_index++) {
        const struct mach_header *header = _dyld_get_image_header(image_index);
        intptr_t slide             = _dyld_get_image_vmaddr_slide(image_index);
        const char *name           = _dyld_get_image_name(image_index);

        // Move ptr over mach header, offset depends on header size
        bool is64 = (header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM_64);
        const uint8_t *ld_cmd_ptr = (const uint8_t *)header
                              + (is64 ? sizeof(struct mach_header_64)
                                     : sizeof(struct mach_header));
        cpu_type_t type = header->cputype;
        cpu_subtype_t subtype = header->cpusubtype & ~CPU_SUBTYPE_MASK;

        // we iterate over load commands and finds __TEXT segments.
        // Note: vmaddr is the intended load address of the Mach-O binary, 
        // it is adjusted by the ASLR slide to give the runtime address
        for (int load_command_index = 0; load_command_index < header->ncmds; load_command_index++) {
            const struct load_command *ld_cmd = (const struct load_command *)ld_cmd_ptr;

            if (ld_cmd->cmd == LC_SEGMENT) {
                const struct segment_command *seg = (const struct segment_command *)ld_cmd;
                if (strcmp(seg->segname, "__TEXT") == 0) {
                    uintptr_t start = seg->vmaddr + slide;
                    uintptr_t end   = start + seg->vmsize;
                    
                    memcpy(all_libs[libs_count].dl_name, name, sizeof(all_libs[libs_count].dl_name));
                    all_libs[libs_count].dl_name[sizeof(all_libs[libs_count].dl_name) - 1] = 0; //truncates string
                    all_libs[libs_count].dl_seg_slide = slide;
                    all_libs[libs_count].dl_seg_start_addr = start;
                    all_libs[libs_count].dl_seg_end_addr = end;
                    
                    if (type == CPU_TYPE_I386) {
                        strlcpy(all_libs[libs_count].dl_arch, "i386", arch_size);
                    } else if (type == CPU_TYPE_ARM) {
                        strlcpy(all_libs[libs_count].dl_arch, "arm", arch_size);
                    } else {
                        strlcpy(all_libs[libs_count].dl_arch, "unknown", arch_size);
                    }
                    
                    libs_count++;
                }
            } else if (ld_cmd->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *seg = (const struct segment_command_64 *)ld_cmd;
                if (strcmp(seg->segname, "__TEXT") == 0) {
                    uintptr_t start = seg->vmaddr + slide;
                    uintptr_t end   = start + seg->vmsize;
                    
                    memcpy(all_libs[libs_count].dl_name, name, sizeof(all_libs[libs_count].dl_name));
                    all_libs[libs_count].dl_name[sizeof(all_libs[libs_count].dl_name) - 1] = 0; //truncates string
                    all_libs[libs_count].dl_seg_slide = slide;
                    all_libs[libs_count].dl_seg_start_addr = start;
                    all_libs[libs_count].dl_seg_end_addr = end;
                    
                    if (type == CPU_TYPE_X86_64) {
                        strlcpy(all_libs[libs_count].dl_arch, "x86_64", arch_size);
                    } else if (type == CPU_TYPE_ARM64_32) {
                        strlcpy(all_libs[libs_count].dl_arch, "arm64_32", arch_size);
                    } else if (type == CPU_TYPE_ARM64) {
                        if (subtype == CPU_SUBTYPE_ARM64E) {
                            strlcpy(all_libs[libs_count].dl_arch, "arm64e", arch_size);
                        } else {
                            strlcpy(all_libs[libs_count].dl_arch, "arm64", arch_size);
                        }
                    } else {
                        strlcpy(all_libs[libs_count].dl_arch, "unknown", arch_size);
                    }
                    
                    libs_count++;
                }
            }
            ld_cmd_ptr += ld_cmd->cmdsize;
        }
    }
    // libs above capacity are ignored
    *all_libs_count = SWIPR_MIN(all_libs_capacity, libs_count);
    return 0;
}

int swipr_os_dep_set_current_thread_name(const char *name) {
    if (pthread_setname_np(name)){
        return -1;
    }
    return 0;
}

int swipr_os_dep_get_current_thread_name(char *name, size_t len) {
    if (pthread_getname_np(pthread_self(), name, len)){
        return -1;
    }
    return 0;
}

static void swipr_resume_thread(thread_act_t thread) {
    kern_return_t kret = thread_resume(thread);
    // We hold a suspension, so resume fails only for a thread that exited meanwhile.
    swipr_precondition(kret == KERN_SUCCESS || kret == MACH_SEND_INVALID_DEST || kret == KERN_INVALID_ARGUMENT ||
                       kret == KERN_TERMINATED || kret == MIG_SERVER_DIED);
}

static int swipr_wait_for_thread_suspend(thread_act_t thread) {
#if TARGET_OS_OSX || TARGET_OS_IOS
    kern_return_t kr;
    thread_basic_info_data_t info;
    mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
    struct timespec start_time = swipr_sampler_get_current_time();
    useconds_t sleep_time = 1;
    float sleep_mult = 1.3;
    
    while (true) {
        count = THREAD_BASIC_INFO_COUNT;
        kr = thread_info(thread,
                         THREAD_BASIC_INFO,
                         (thread_info_t)&info,
                         &count);
        if (kr != KERN_SUCCESS) {
            return 1;
        }
        
        if (info.run_state == TH_STATE_WAITING) {
            return 0;
        }
        // abort incase thread is uninterruptable
        if (info.run_state == TH_STATE_UNINTERRUPTIBLE) {
            thread_abort(thread);
            continue;
        }
        usleep(sleep_time);
        struct timespec current_time = swipr_sampler_get_current_time();
        float duration = (current_time.tv_sec - start_time.tv_sec) +
                         (current_time.tv_nsec - start_time.tv_nsec) / 1e9f;
        
        if (duration > SWIPR_NSEC_PER_SEC) {
            // abandon thread
            UNSAFE_DEBUG("Thread timed out during suspension \n");
            return 1;
        }
        
        // update sleep_time
        sleep_time = (useconds_t) sleep_time * sleep_mult;
    }
    return 0;
#else
    return 1;
#endif
}

bool swipr_os_dep_copy_memory(void *dst, uintptr_t src, size_t len) {
    // Other threads run while the target is suspended, e.g. pthread_join freeing an exiting thread's top stack page, so
    // a plain load can fault; the kernel copy fails instead. mincore reports unmapped pages as mapped on Darwin.
    mach_vm_size_t size = 0;
    kern_return_t kret = mach_vm_read_overwrite(mach_task_self(), src, len, (mach_vm_address_t)dst, &size);
    return kret == KERN_SUCCESS && size == len;
}

int swipr_os_dep_sample_prepare(size_t num_threads, struct thread_info *all_threads, struct swipr_minidump *minidumps) {
    // The stack stays: swipr_os_dep_sample_threads repeats it if the same thread has not run since.
    for (int i=0; i<num_threads; i++) {
        minidumps[i].md_last_tid = minidumps[i].md_tid;
        minidumps[i].md_tid = 0;
    }
    return 0;
}

void swipr_os_dep_sample_threads(size_t num_threads, struct thread_info *all_threads, struct swipr_minidump *minidumps,
                                 struct timespec start_time) {
#if TARGET_OS_OSX || TARGET_OS_IOS
    // For Darwin - controller thread suspends and resumes each mutator
    // We ignore thread iff ti_id == 0
    
    for (mach_msg_type_number_t i=0; i<num_threads; i++) {
        // ignore and mark unwanted threads
        if (all_threads[i].ti_id == 0) {
            continue;
        }

        thread_extended_info_data_t info;
        mach_msg_type_number_t info_count = THREAD_EXTENDED_INFO_COUNT;
        if (thread_info(all_threads[i].ti_os_specific.mach_thread, THREAD_EXTENDED_INFO, (thread_info_t)&info, &info_count)
            != KERN_SUCCESS) {
            all_threads[i].ti_id = 0;
            continue;
        }
        uint64_t cpu_ns = info.pth_user_time + info.pth_system_time;
        // A waiting thread whose CPU time has not moved has not run since its last unwind, so its stack is unchanged.
        if (minidumps[i].md_last_tid == all_threads[i].ti_id && info.pth_run_state == TH_STATE_WAITING
            && cpu_ns == minidumps[i].md_last_cpu_ns) {
            minidumps[i].md_tid = all_threads[i].ti_id;
            minidumps[i].md_time = start_time;
            strcpy(minidumps[i].md_thread_name, all_threads[i].ti_name);
            continue;
        }
        minidumps[i].md_last_cpu_ns = cpu_ns;

        g_swipr_c2ms.c2ms_c2ms[i].c2m_thread_id = all_threads[i].ti_id;
        kern_return_t kret = thread_suspend(all_threads[i].ti_os_specific.mach_thread);
        if (kret != KERN_SUCCESS) {
            // if thread is dead then ignore error and mark ignore
            all_threads[i].ti_id = 0;
            continue;
        }
        
        // skip thread if it died during wait
        int has_suspended = swipr_wait_for_thread_suspend(all_threads[i].ti_os_specific.mach_thread);
        if (has_suspended != 0) {
            all_threads[i].ti_id = 0;
            swipr_resume_thread(all_threads[i].ti_os_specific.mach_thread);
            continue;
        }
        
#if defined(__x86_64__)
        x86_thread_state64_t state = { 0 };
        mach_msg_type_number_t count = x86_THREAD_STATE64_COUNT;
        thread_state_flavor_t flavor = x86_THREAD_STATE64;
        
        kret = thread_get_state(all_threads[i].ti_os_specific.mach_thread, flavor, (thread_state_t)&state, &count);

        g_swipr_c2ms.c2ms_c2ms[i].c2m_tiny_context.sfuctx_fp = state.__rbp;
        g_swipr_c2ms.c2ms_c2ms[i].c2m_tiny_context.sfuctx_sp = state.__rsp;
        g_swipr_c2ms.c2ms_c2ms[i].c2m_tiny_context.sfuctx_ip = state.__rip;
#elif defined(__aarch64__)
        arm_thread_state64_t state = { 0 };
        mach_msg_type_number_t count = ARM_THREAD_STATE64_COUNT;
        thread_state_flavor_t flavor = ARM_THREAD_STATE64;

        kret = thread_get_state(all_threads[i].ti_os_specific.mach_thread, flavor, (thread_state_t)&state, &count);


        g_swipr_c2ms.c2ms_c2ms[i].c2m_tiny_context.sfuctx_fp = arm_thread_state64_get_fp(state);
        g_swipr_c2ms.c2ms_c2ms[i].c2m_tiny_context.sfuctx_sp = arm_thread_state64_get_sp(state);
        g_swipr_c2ms.c2ms_c2ms[i].c2m_tiny_context.sfuctx_ip = arm_thread_state64_get_pc(state);
#else
#warning unknown OS/arch combination
        g_swipr_c2ms.c2ms_c2ms[i].c2m_tiny_context.sfuctx_fp = 0;
        g_swipr_c2ms.c2ms_c2ms[i].c2m_tiny_context.sfuctx_sp = 0;
        g_swipr_c2ms.c2ms_c2ms[i].c2m_tiny_context.sfuctx_ip = 0;
#endif
        if (kret == KERN_SUCCESS) {
            swipr_sampler_unwind_thread(i, &minidumps[i], all_threads[i].ti_name, start_time);
        } else {
            // Usually the thread exited after thread_suspend, but XNU also returns KERN_ABORTED for a live thread.
            all_threads[i].ti_id = 0;
        }
        swipr_resume_thread(all_threads[i].ti_os_specific.mach_thread);
    }
#endif
}

int swipr_os_dep_sample_cleanup(size_t num_threads, struct thread_info *all_threads) {
#if TARGET_OS_OSX || TARGET_OS_IOS
    // swipr_os_dep_sample_threads resumes each thread it suspended.
    return swipr_os_dep_destroy_thread_list(all_threads);
#else
    return 1; // unsupported OS
#endif
}

#endif
