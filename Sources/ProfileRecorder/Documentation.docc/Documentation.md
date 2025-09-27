# ``ProfileRecorder``

An in-process sampler to capture performance traces for your app.

## Overview

To retrieve samples for you app, have your app invoke:

```swift
ProfileRecorderSampler.sharedInstance.requestSamples(
    outputFilePath: "/tmp/samples",
    count: 1_000,
    timeBetweenSamples: .milliseconds(10),
    eventLoop: loop
)
```

The example above creates 1000 samples with 10 ms between each sample. With this configuration, 
the profile recording server will capture samples over about 10 seconds.
After that, you'll need to (on the machine you're running it) convert the samples into a regular format and symbolicate it.

Optionally, you can have `llvm-symbolizer` symbolise your samples.
You can request this by passing `--use-native-symbolizer false` to `swipr-sample-conv`. 
By default (as of Swift Profile Recorder 0.2.6), it will use ProfileRecorder's native symboliser.

That can be done using the command:

```bash
swipr-sample-conv < /tmp/samples | swift demangle --simplified > /tmp/stacks.perf
```

> Note: `swipr-sample-conv` _must_ be run on a system that has access to the very same files in the same versions as the system where the samples were obtained. 
Usually this means that you need to run them in a Docker container with the exact same image as what you were running in production.
It can be another container but it needs to have the same files at the same paths to be able to symbolicate the traces.
## Topics

### In-process sampler

- ``ProfileRecorderSampler``
