#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Profile Recorder open source project
##
## Copyright (c) 2025 Apple Inc. and the Swift Profile Recorder project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

set -eu

here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
swift_root=${1:-$here/../../swift}
backtracing_root="$swift_root"/stdlib/public/RuntimeModule
# (no prefixes just yet) prefix=${2:-SWIPR}

function die() {
    echo "ERROR: $*"
    exit 1
}

echo "Using backtracing_root from $backtracing_root"
test -d "$backtracing_root" || die "$backtracing_root: Not found"

target_c_src="$here/../Sources/CProfileRecorderDarwin"
target_swift_src="$here/../Sources/ProfileRecorderSampleConversion/CoreSymbolication"
desc=$(cd "$backtracing_root" && git describe --abbrev --dirty)
echo "$desc" > "$here/../Misc/vendored-core-symbolication.version"

rm -rf "$target_c_src"
rm -f "$target_swift_src/CoreSymbolication.swift"
mkdir -p "$target_c_src/include"
cat > "$target_c_src/empty.c" <<"EOF"
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2021-2025 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
EOF

cat > "$target_c_src/include/CProfileRecorderDarwin.h" <<"EOF"
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2021-2025 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#pragma once

#include "swipr-core-symbolication.h"
EOF

cp "$backtracing_root"/modules/OS/Darwin.h "$target_c_src/include/swipr-core-symbolication.h"

vendored_file_text='//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift Profile Recorder project authors
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
'

find . -name "swipr-core-symbolication.h" -exec gsed -ri \
    -e "s/SWIFT_BACKTRACING_DARWIN_H/SWIPR_CORE_SYMBOLICATION_H/g" \
    -e "/#include <mach\/mach_vm\.h>/d" \
    -e "/#include <libproc\.h>/d" \
    -e "0,/#include .*/{/#include .*/a\#include <stdbool.h>
}" \
    -e "/enum CFStringBuiltInEncodings: CFStringEncoding \{/,/^};/d" \
    -e "1s%^%$(echo "$vendored_file_text" | tr '\n' '%' | sed 's/%/\\n/g' | sed 's/\\n$//'  )%" \
    '{}' \;
    

cp "$backtracing_root/CoreSymbolication.swift" "$target_swift_src/CoreSymbolication.swift"

find . -name "CoreSymbolication.swift" -exec gsed -ri \
    -e "s/private framework/TEMP_PLACEHOLDER/g" \
    -e "s/private//g" \
    -e "s/TEMP_PLACEHOLDER/private framework/g" \
    -e "s/internal import .*//g" \
    -e '/^import .*$/a\
import Darwin\
import Foundation\
import CProfileRecorderDarwin
        ' \
    -e '/^typealias .*$/a\
typealias CSTypeRef = CProfileRecorderDarwin.CSTypeRef\
typealias CSBinaryImageInformation = CProfileRecorderDarwin.CSBinaryImageInformation\
typealias CSNotificationBlock = CProfileRecorderDarwin.CSNotificationBlock\
typealias CSSymbolicatorRef = CProfileRecorderDarwin.CSSymbolicatorRef\
typealias CFUUIDBytes = CProfileRecorderDarwin.CFUUIDBytes
        ' \
    -e '/Crash Reporter support/,/Base functionality/{//!d;}' \
    -e "1s%^%$(echo "$vendored_file_text" | tr '\n' '%' | sed 's/%/\\n/g' | sed 's/\\n$//'  )%" \
    '{}' \;
    
echo "Okay, all done."
