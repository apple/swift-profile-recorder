#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Profile Recorder open source project
##
## Copyright (c) 2026 Apple Inc. and the Swift Profile Recorder project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##
set -euo pipefail

here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$here"

config="${1:-release}"

echo "Building: ${config}"
swift build -Xswiftc "-sanitize=fuzzer,address" -Xswiftc -parse-as-library -Xswiftc -enable-testing -c "${config}" --product FuzzELF
echo "Binary: $here/.build/${config}/FuzzELF"
