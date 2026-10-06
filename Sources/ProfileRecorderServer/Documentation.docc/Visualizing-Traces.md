# Visualing Traces

Convert the raw performance traces from Swift Profile Recorder into visualizations to analyze the performance of your app.

## Overview

Several performance traces tools exist to provide visualizations you can use to explore the performance of your app.
The following sections outline open source tools you can use to create and review the visualizations. 

### FlameGraphs

Repository: https://github.com/brendangregg/Flamegraph

```bash
FlameGraph/stackcollapse-perf.pl < /tmp/samples.perf | FlameGraph/flamegraph.pl > /tmp/samples.svg
open /tmp/samples.svg
```

### Firefox Profiler (https://profiler.firefox.com):

How to use Firefox Profiler?

1. Open https://profiler.firefox.com and drag /tmp/samples.svg onto it.
2. Click "Show all tracks" in "tracks" menu on the top left
3. Slightly further down, select the first thread (track), hold Shift and select the last thread.
4. Open the "Flame Graph" tab

### Pyroscope

[Pyroscope](https://pyroscope.io) is an OSS continuous profiling service.

The following command illustrates requesting samples from Swift Profile Recorder running on a UNIX domain socket, demangling the symbols, and submitting it results into Pyroscope:

```
curl -s -d '{"numberOfSamples":100,"timeInterval":"100 ms"}' --unix-socket /var/run/swipr-pid-1.sock http://unix | \
    c++filt -n | swift demangle --simplified | \
    FlameGraph/stackcollapse-perf.pl | \
    cut -d';' -f2- | \
    curl --data-binary @- "http://YOUR_PYROSCOPE_SERVER:4040/ingest?name=YOUR_APP&sampleRate=10&from=$(( $(date +%s) - 10 ))"
```

With Swift 6.4+ on macOS 27+ or Linux, add `"demangle":true` to the request body to get demangled symbols and drop the `swift demangle` step.

### Other options

Check https://profilerpedia.markhansen.co.nz/formats/linux-perf-script/#converts-to-transitive for
a list of visualisation options for the "Linux perf script" format that Swift Profile Recorder produces.

