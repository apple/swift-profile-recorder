//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
// This file has been adjusted for ProfileRecorder, originally of the Swift.org open source project
// swift-format-ignore-file

//===--- Libc.swift - libc utility functions ------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Since we are using C++ interop, some utility functions we've defined in
// modules/OS/Libc.h end up in a namespace.  This file moves them out again.
//
//===----------------------------------------------------------------------===//

import CProfileRecorderSwiftELF

let SWIPR_swift_open = CProfileRecorderSwiftELF.SWIPR_swift_open
let SWIPR_swift_get_errno = CProfileRecorderSwiftELF.SWIPR_swift_get_errno
let SWIPR_swift_set_errno = CProfileRecorderSwiftELF.SWIPR_swift_set_errno
