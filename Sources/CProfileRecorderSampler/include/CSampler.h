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

#ifndef CSampler_h
#define CSampler_h

#include <unistd.h>
#include <stdio.h>
#include <stdbool.h>

struct swipr_per_sample_information;

size_t swipr_per_sample_information_get_samples_taken(struct swipr_per_sample_information * _Nonnull per_sample_info);

int swipr_request_sample(FILE * _Nonnull output,
                         bool (* _Nonnull should_take_more_samples)(
                                                          void * _Nullable context,
                                                          struct swipr_per_sample_information * _Nonnull per_sample_info
                                                          ),
                         void * _Nullable context,
                         size_t sample_count_hint,
                         useconds_t usecs_between_samples);
int swipr_initialize(void);

#endif /* CSampler_h */
