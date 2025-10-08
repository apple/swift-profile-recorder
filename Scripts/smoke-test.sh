#!/bin/bash

set -eu
output=${1:?output directory}

tmpdir=$(mktemp -d /tmp/swipr_smoke_XXXXXX)
trap 'rm -rf "$tmpdir"' EXIT

here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$here"
swift build -c release --scratch-path "$tmpdir"/build
mkdir -p "$output"

socket_path="$tmpdir/swipr.sock"

PROFILE_RECORDER_SERVER_URL=unix://"$socket_path" \
    "$tmpdir"/build/release/swipr-mini-demo \
    --blocking --burn-cpu --array-appends \
    --tsp true \
    --output "$output"/samples.swipr \
    --iterations 1000 \
    --profiling-server &
demo_pid=$!
sleep 3

set -x
curl -o "$output"/samples.perf \
    -sd '{"timeInterval":"100 ms","numberOfSamples":100}' \
    --unix-socket "$socket_path" \
    http://unix/sample
curl -o "$output"/samples.pprof \
    -s \
    --unix-socket "$socket_path" \
    http://unix/debug/pprof/profile?seconds=10
curl -o "$output"/samples-fakesym.pprof \
    -s \
    --unix-socket "$socket_path" \
    http://unix/debug/pprof/symbolizer=fake/profile?seconds=10
kill "$demo_pid"
wait "$demo_pid" || true

