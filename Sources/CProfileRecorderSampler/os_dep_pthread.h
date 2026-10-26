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

#ifndef swipr_os_dep_pthread_h
#define swipr_os_dep_pthread_h

#include <pthread.h>
#include <stdlib.h>
#include <sys/time.h>
#include <sys/errno.h>

#include "asserts.h"
#include "os_dep_linux.h"
#include "common.h"

struct swipr_pthread_sem {
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    int value;
};

typedef struct swipr_pthread_sem *swipr_os_dep_sem;
static inline swipr_os_dep_sem
swipr_os_dep_sem_create(int value) {
    struct swipr_pthread_sem *sem = malloc(sizeof(*sem));
    if (!sem) {
        return NULL;
    }

    *sem = (typeof(*sem)){ 0 };
    sem->value = value;

    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ERRORCHECK);
    pthread_mutex_init(&sem->mutex, &attr);

    pthread_cond_init(&sem->cond, NULL);

    return sem;
}

static inline void
swipr_os_dep_sem_free(swipr_os_dep_sem sem) {
    int err = pthread_cond_destroy(&sem->cond);
    swipr_precondition(err == 0);

    err = pthread_mutex_destroy(&sem->mutex);
    swipr_precondition(err == 0);

    free(sem);
}

static inline void
swipr_os_dep_sem_signal(swipr_os_dep_sem sem) {
    int err = pthread_mutex_lock(&sem->mutex);
    swipr_precondition(err == 0);

    swipr_precondition(sem->value >= 0);
    sem->value++;

    // Under the mutex: once it is released the waiter may return and free the semaphore.
    err = pthread_cond_signal(&sem->cond);
    swipr_precondition(err == 0);

    err = pthread_mutex_unlock(&sem->mutex);
    swipr_precondition(err == 0);
}

#define swipr_os_dep_deadline struct timespec

static inline swipr_os_dep_deadline
swipr_os_dep_create_deadline(uint64_t nsecs) {
    struct timeval cur_time = { 0 };
    gettimeofday(&cur_time, NULL);

    uint64_t all_nsecs = nsecs + ((uint64_t)cur_time.tv_usec * 1000ULL);
    struct timespec timeout_abs = {
        .tv_sec = cur_time.tv_sec + (all_nsecs / SWIPR_NSEC_PER_SEC),
        .tv_nsec = all_nsecs % SWIPR_NSEC_PER_SEC
    };

    return timeout_abs;
}

static inline void
swipr_os_dep_sem_wait(swipr_os_dep_sem sem) {
    int err = pthread_mutex_lock(&sem->mutex);
    swipr_precondition(err == 0);

    swipr_precondition(sem->value >= 0);
    while (sem->value <= 0) {
        err = pthread_cond_wait(&sem->cond, &sem->mutex);
        swipr_precondition(err == 0);
    }
    sem->value--;
    swipr_precondition(sem->value >= 0);

    err = pthread_mutex_unlock(&sem->mutex);
    swipr_precondition(err == 0);
}

static inline int
swipr_os_dep_sem_wait_with_deadline(swipr_os_dep_sem sem, swipr_os_dep_deadline deadline) {
    // The post is usually microseconds away; spinning first skips the scheduler wake-up of a sleeping waiter.
    for (int spin = 0; spin < 2000 && __atomic_load_n(&sem->value, __ATOMIC_ACQUIRE) <= 0; spin++) {
#if defined(__x86_64__)
        __builtin_ia32_pause();
#elif defined(__aarch64__) || defined(__arm__)
        __asm__ volatile("yield");
#endif
    }
    int err = pthread_mutex_lock(&sem->mutex);
    swipr_precondition(err == 0);

    while (sem->value <= 0) {
        err = pthread_cond_timedwait(&sem->cond, &sem->mutex, &deadline);
        if (err == ETIMEDOUT) {
            err = pthread_mutex_unlock(&sem->mutex);
            swipr_precondition(err == 0);

            return ETIMEDOUT;
        }
        swipr_precondition(err == 0);
    }
    sem->value--;
    swipr_precondition(sem->value >= 0);

    err = pthread_mutex_unlock(&sem->mutex);
    swipr_precondition(err == 0);

    return 0;
}

#endif /* swipr_os_dep_pthread_h */
