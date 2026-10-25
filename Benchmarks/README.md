# Benchmarks

```
cd Benchmarks
swift package --disable-sandbox benchmark --target SamplingOverheadBenchmarks
swift package --disable-sandbox benchmark --target ConversionBenchmarks
```

## SamplingOverheadBenchmarks

Measures what sampling costs the profiled process. Each benchmark starts 10, 50, 100 or 900 threads, each 30-60 frames deep. 10% of them (at most half the cores) spin on the CPU, the rest block. The process's own threads (main, one NIO event loop) are sampled too. The sampler handles at most 1024 threads.

A tick is one pass of the sampler over every thread in the process: stop it, copy its stack, write it out, let it run again. Each thread's stack from a tick is one sample.

- `cost: N threads`, metric `Sampler time per tick (us)`: wall time of one tick, ticks run back to back. Includes the per-request setup (opening the output file, writing the list of loaded libraries) spread over the ticks. 1400 at 100 threads means one pass over all 100 threads takes 1.4 ms.
- `pause at 100 Hz: N threads`, metric `Pause per busy thread per tick (us)`: how long each spinning thread is stopped during one tick, with a tick every 10 ms. Each spinning thread reads the clock in a loop and counts any gap over 10 us as stopped. 400 at 100 threads means each spinning thread loses 400 us of every 10 ms, 4% of its CPU time. Blocked threads are stopped too, but are not running to notice.
- `pause at 100 Hz: no sampler, N busy`: the same spinning threads with no sampler, so the gaps come from the scheduler and interrupts alone. Subtract it from the `pause at 100 Hz: N threads` results.

## ConversionBenchmarks

Converts recorded samples to perf script and pprof formats.
