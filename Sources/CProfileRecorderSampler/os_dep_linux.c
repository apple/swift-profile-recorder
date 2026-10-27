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

#if __linux__

#define _GNU_SOURCE
#include <dirent.h>
#include <sys/errno.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <link.h>
#include <string.h>
#include <fcntl.h>
#include <sys/uio.h>

#include "os_dep.h"
#include "interface.h"
#include "common.h"

// Reads the name, the state ('R' = running or runnable) and whether SIGPROF is blocked from /proc/self/task/<tid>/stat,
// one file instead of status and comm.
// Returns: 0 on success, -1 on error.
static int swipr_read_thread_stat(swipr_os_dep_thread_id tid, char *name, size_t name_size, char *state, bool *sigprof_blocked) {
    char path[64];
    snprintf(path, sizeof(path), "/proc/self/task/%d/stat", tid);

    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        return -1;
    }

    char buffer[1024];
    ssize_t bytes_read = read(fd, buffer, sizeof(buffer) - 1);
    int close_result = close(fd);
    if (bytes_read <= 0 || (close_result != 0 && !(close_result == -1 && errno == EINTR))) {
        return -1;
    }
    buffer[bytes_read] = '\0';

    // Field 2 is the name in parentheses; it may itself contain ')', so the last one ends it.
    const char *name_start = strchr(buffer, '(');
    const char *name_end = strrchr(buffer, ')');
    if (!name_start || !name_end || name_end < name_start) {
        return -1;
    }
    name_start++;
    size_t name_length = (size_t)(name_end - name_start);
    if (name_length >= name_size) {
        name_length = name_size - 1;
    }

    // Field 32 is the blocked mask in decimal; it covers signals 1-31 only, SIGPROF included.
    const char *field = name_end + 2;
    for (int field_number = 3; field_number < 32; field_number++) {
        field = strchr(field, ' ');
        if (!field) {
            return -1;
        }
        field++;
    }
    unsigned long long mask = strtoull(field, NULL, 10);
    // Field 3 is the state; read once the walk above shows the fields after the name exist.
    *state = name_end[2];

    memcpy(name, name_start, name_length);
    name[name_length] = '\0';
    *sigprof_blocked = (mask & (1ULL << (SIGPROF - 1))) != 0;
    return 0;
}

struct thread_info *swipr_os_dep_create_thread_list(size_t *all_threads_count, enum swipr_sampling_mode mode) {
    struct thread_info *all_threads = calloc(sizeof(struct thread_info), SWIPR_MAX_MUTATOR_THREADS);
    if (!all_threads) {
        return NULL;
    }
    DIR *dir = opendir("/proc/self/task");
    if (!dir) {
        goto error;
    }
    int next_index = 0;
    pid_t my_tid = swipr_os_dep_get_thread_id();
    
    struct dirent *ent = NULL;
    while (next_index < SWIPR_MAX_MUTATOR_THREADS) {
        errno = 0;
        ent = readdir(dir);
        if (ent == NULL) {
            switch (errno) {
                case 0:
                    goto out;
                case EINTR:
                    continue;
                default:
                    goto error;
            }
            if (errno == EINTR) {
                continue;
            }
        }
        
        pid_t tid = atol(ent->d_name);
        if (tid != 0 && tid != my_tid) {
            struct thread_info *thread = &all_threads[next_index];
            // CPU mode reads this in swipr_signal_thread instead: the state goes stale for threads that run in bursts.
            if (mode == SWIPR_SAMPLING_WALL) {
                bool sigprof_blocked = false;
                char state = 0;
                if (swipr_read_thread_stat(tid, thread->ti_name, sizeof(thread->ti_name), &state, &sigprof_blocked) != 0) {
                    thread->ti_name[0] = '\0';
                } else if (sigprof_blocked) {
                    // Skip threads that have SIGPROF blocked
                    continue;
                }
            }
            next_index++;
            thread->ti_id = tid;
        }
    }
    
out:
    closedir(dir);
    *all_threads_count = next_index;
    return all_threads;
error:
    if (dir) {
        closedir(dir);
    }
    swipr_os_dep_destroy_thread_list(all_threads);
    *all_threads_count = 0;
    return NULL;
}

int swipr_os_dep_destroy_thread_list(struct thread_info *thread_list) {
    swipr_precondition(thread_list);
    free(thread_list);
    return 0;
}

struct dl_iterate_phdr_data {
    struct swipr_dynamic_lib *dli_all_libs;
    size_t dli_all_libs_capacity;
    size_t dli_all_libs_count;
    bool dli_first;
};

static int
dl_iterate_phdr_cb(struct dl_phdr_info *info, size_t size, void *v_data) {
    struct dl_iterate_phdr_data *data = (typeof(data))v_data;

    for (int i=0; i<info->dlpi_phnum; i++) {
        const ElfW(Phdr) *phdr = &info->dlpi_phdr[i];
        if (phdr->p_type != PT_LOAD) {
            continue;
        }

        struct swipr_dynamic_lib *my_lib = &data->dli_all_libs[data->dli_all_libs_count++];
        if (data->dli_first) {
            readlink("/proc/self/exe", my_lib->dl_name, sizeof(my_lib->dl_name));
        } else {
            strncpy(my_lib->dl_name, info->dlpi_name, sizeof(my_lib->dl_name));
        }
        my_lib->dl_name[sizeof(my_lib->dl_name) - 1] = 0;

        my_lib->dl_seg_slide = info->dlpi_addr;
        my_lib->dl_seg_start_addr = info->dlpi_addr + phdr->p_vaddr;
        my_lib->dl_seg_end_addr = info->dlpi_addr + phdr->p_vaddr + phdr->p_memsz;
    }
    data->dli_first = false;

    return 0;
}

int swipr_os_dep_list_all_dynamic_libs(struct swipr_dynamic_lib *all_libs,
                                 size_t all_libs_capacity,
                                 size_t *all_libs_count) {
    struct dl_iterate_phdr_data data = {
        .dli_all_libs = all_libs,
        .dli_all_libs_capacity = all_libs_capacity,
        .dli_all_libs_count = 0,
        .dli_first = true,
    };
    size_t next = 0;
    int err = dl_iterate_phdr(dl_iterate_phdr_cb, &data);
    *all_libs_count = data.dli_all_libs_count;

    return err;
}

int swipr_os_dep_set_current_thread_name(const char *name) {
    return pthread_setname_np(pthread_self(), name);
}

int swipr_os_dep_get_current_thread_name(char *name, size_t len) {
#ifdef __ANDROID__
    if (len < 16) {
        return -1;
    }
    return TEMP_FAILURE_RETRY(prctl(PR_GET_NAME, name)) == -1 ? -1 : 0;
#else
    return pthread_getname_np(pthread_self(), name, len);
#endif
}

// Set per request: getpid is a syscall, and a forked child must not read its parent.
static pid_t g_swipr_pid;

// Set once seccomp or an old kernel refuses process_vm_readv.
static _Atomic bool g_swipr_vm_readv_denied;

bool swipr_os_dep_copy_memory(void *dst, uintptr_t src, size_t len) {
    // A frame chain through code without frame pointers can point anywhere; the kernel copy fails with EFAULT instead.
    if (!g_swipr_vm_readv_denied) {
        struct iovec local = { .iov_base = dst, .iov_len = len };
        struct iovec remote = { .iov_base = (void *)src, .iov_len = len };
        if (process_vm_readv(g_swipr_pid, &local, 1, &remote, 1, 0) == (ssize_t)len) {
            return true;
        }
        if (errno != EPERM && errno != ENOSYS) {
            return false;
        }
        g_swipr_vm_readv_denied = true;
    }
    // The target is parked in its signal handler, so its stack stays mapped; only a garbage frame pointer can fault.
    memcpy(dst, (const void *)src, len);
    return true;
}

int swipr_os_dep_sample_prepare(size_t num_threads, struct thread_info *all_threads, struct swipr_minidump *minidumps) {
    g_swipr_pid = getpid();
    for (int i=0; i<num_threads; i++) {
        swipr_precondition(all_threads[i].ti_id != 0);
        g_swipr_c2ms.c2ms_c2ms[i].c2m_thread_id = all_threads[i].ti_id;
        swipr_precondition(g_swipr_c2ms.c2ms_c2ms[i].c2m_proceed == NULL);
        g_swipr_c2ms.c2ms_c2ms[i].c2m_proceed = swipr_os_dep_sem_create(0);
        swipr_precondition(g_swipr_c2ms.c2ms_c2ms[i].m2c_proceed == NULL);
        g_swipr_c2ms.c2ms_c2ms[i].m2c_proceed = swipr_os_dep_sem_create(0);
    }

    // checks threads, if out of memory then free all
    for (int i=0; i<num_threads; i++) {
        if (g_swipr_c2ms.c2ms_c2ms[i].c2m_proceed == NULL || g_swipr_c2ms.c2ms_c2ms[i].m2c_proceed == NULL) {
            // out of memory.

            for (int j=0; j<num_threads; j++) {
                if (g_swipr_c2ms.c2ms_c2ms[j].c2m_proceed) {
                    swipr_os_dep_sem_free(g_swipr_c2ms.c2ms_c2ms[j].c2m_proceed);
                    g_swipr_c2ms.c2ms_c2ms[j].c2m_proceed = NULL;
                }
                if (g_swipr_c2ms.c2ms_c2ms[j].m2c_proceed) {
                    swipr_os_dep_sem_free(g_swipr_c2ms.c2ms_c2ms[j].m2c_proceed);
                    g_swipr_c2ms.c2ms_c2ms[j].m2c_proceed = NULL;
                }
            }

            return 1;
        }
    }

    for (int i=0; i<num_threads; i++) {
        minidumps[i] = (typeof(minidumps[i])){ 0 };
    }
    return 0;
}

static void swipr_signal_thread(int i, struct thread_info *all_threads, swipr_os_dep_deadline tick_deadline,
                                enum swipr_sampling_mode mode) {
    swipr_precondition(all_threads[i].ti_id != 0);
    swipr_os_dep_deadline now = swipr_os_dep_create_deadline(0);
    if (now.tv_sec > tick_deadline.tv_sec
        || (now.tv_sec == tick_deadline.tv_sec && now.tv_nsec >= tick_deadline.tv_nsec)) {
        g_swipr_c2ms.c2ms_c2ms[i].c2m_thread_id = 0;
        return;
    }
    if (mode == SWIPR_SAMPLING_CPU) {
        // Read right before signalling; a state read while listing goes stale for threads that run in short bursts.
        bool sigprof_blocked = false;
        char state = 0;
        if (swipr_read_thread_stat(all_threads[i].ti_id, all_threads[i].ti_name, sizeof(all_threads[i].ti_name), &state,
                                   &sigprof_blocked) != 0) {
            all_threads[i].ti_name[0] = '\0';
        }
        if (sigprof_blocked || state != 'R') {
            g_swipr_c2ms.c2ms_c2ms[i].c2m_thread_id = 0;
            return;
        }
    }
    UNSAFE_DEBUG("signalling thread %lu\n", (uintptr_t)all_threads[i].ti_id);
    if (swipr_os_dep_kill(all_threads[i].ti_id, SIGPROF) != 0) {
        UNSAFE_DEBUG("couldn't signal thread %lu\n", (uintptr_t)all_threads[i].ti_id);
        g_swipr_c2ms.c2ms_c2ms[i].c2m_thread_id = 0;
    }
}

void swipr_os_dep_sample_threads(size_t num_threads, struct thread_info *all_threads, struct swipr_minidump *minidumps,
                                 struct timespec start_time, enum swipr_sampling_mode mode) {
    int err;
    // Threads not signalled once a tick has spent this long are skipped, so stragglers can't stretch a tick to minutes.
    swipr_os_dep_deadline tick_deadline = swipr_os_dep_create_deadline(SWIPR_NSEC_PER_SEC);
    if (num_threads > 0) {
        swipr_signal_thread(0, all_threads, tick_deadline, mode);
    }
    for (int i=0; i<num_threads; i++) {
        swipr_os_dep_thread_id thread_id = g_swipr_c2ms.c2ms_c2ms[i].c2m_thread_id;
        if (thread_id != 0) {
            // Kept long: a handler that answers after the timeout is not cancelled and is unsafe (see FIXME below).
            swipr_os_dep_deadline deadline = swipr_os_dep_create_deadline(SWIPR_NSEC_PER_SEC);
            err = swipr_os_dep_sem_wait_with_deadline(g_swipr_c2ms.c2ms_c2ms[i].m2c_proceed, deadline);
            if (err) {
                if (swipr_os_dep_kill(thread_id, 0) == -1 && errno == ESRCH) {
                    UNSAFE_DEBUG("thread %d/%ld died, that's probably okay\n", i, (long)thread_id);
                } else {
                    UNSAFE_DEBUG("OUCH, timeout, thread still alive but no response %d/%ld of %zu\n",
                                 i, (long)thread_id, num_threads);
                    // FIXME: We can't just continue here...
                }
                g_swipr_c2ms.c2ms_c2ms[i].c2m_thread_id = 0;
                thread_id = 0;
            }
        }
        // The next signal's delivery overlaps this unwind. Sent only once thread i is parked or skipped, and thread i
        // is released before the next wait: a parked thread can hold a lock the next one needs to take the signal.
        if (i + 1 < num_threads) {
            swipr_signal_thread(i + 1, all_threads, tick_deadline, mode);
        }
        if (thread_id == 0) {
            continue;
        }
        swipr_sampler_unwind_thread(i, &minidumps[i], all_threads[i].ti_name, start_time);
        // c2m_thread_id stays set, so cleanup waits for the handler's exit post before freeing the semaphores.
        swipr_os_dep_sem_signal(g_swipr_c2ms.c2ms_c2ms[i].c2m_proceed);
    }
}

int swipr_os_dep_sample_cleanup(size_t num_threads, struct thread_info *all_threads) {
    for (int i=0; i<num_threads; i++) {
        // Released by swipr_os_dep_sample_threads; its handler posts m2c_proceed on its way out.
        swipr_os_dep_thread_id thread_id = g_swipr_c2ms.c2ms_c2ms[i].c2m_thread_id;
        if (thread_id > 0) {
            swipr_os_dep_deadline deadline = swipr_os_dep_create_deadline(100 * SWIPR_NSEC_PER_MSEC);
            int err = swipr_os_dep_sem_wait_with_deadline(g_swipr_c2ms.c2ms_c2ms[i].m2c_proceed, deadline);
            if (err) {
                UNSAFE_DEBUG("OUTCH, timeout (B), thread %d/%ld of %zu\n",
                             i, (long)thread_id, num_threads);
                // FIXME: Continuing here is unsafe, the tests might still exist, and below, we'll free the semaphore.
                // Probably best to leak it or so.
            }
        }
        g_swipr_c2ms.c2ms_c2ms[i].c2m_thread_id = 0;
        swipr_os_dep_sem_free(g_swipr_c2ms.c2ms_c2ms[i].c2m_proceed);
        swipr_os_dep_sem_free(g_swipr_c2ms.c2ms_c2ms[i].m2c_proceed);
        g_swipr_c2ms.c2ms_c2ms[i].c2m_proceed = NULL;
        g_swipr_c2ms.c2ms_c2ms[i].m2c_proceed = NULL;
    }
    return swipr_os_dep_destroy_thread_list(all_threads);
}


#endif
