# ``ProfileRecorderServer``

Capture performance traces of your app's execution using an in-process profiler.  

## Overview

This package provides a sampling profiler that runs _inside_ your app.
With this profiler, you can capture performance traces without requiring system priveleges such as `CAP_SYS_PTRACE` or direct access to where the executable is running for external tools. 
This enables you to capture profile traces in situations where you don't have access to where your app it running, for example within a cloud service's Lambda function, a remote docker container, or similiar situation.

You can pull it in as a fully self-contained Swift Package Manger dependency and then use it for your app.

The easiest way to use Swift Profile Recorder in your application is to have it run the Swift Profile Recorder Server.
With the profile recording server running, retrieve symbolicated samples with a single `curl` (or any other HTTP client) command.

### Quick Start

Once you have bootstraped the Swift Profile Recorder Server in your application, request samples:

1. Set the environment variable `PROFILE_RECORDER_SERVER_URL=http://127.0.0.1:7377` and run your server
2. Request the samples using the host and port that you defined in the environment variable:

```bash
curl -sd '{"numberOfSamples":100,"timeInterval":"10 ms"}' http://localhost:7377 | \
    swift demangle --simplified > /tmp/samples.perf
```

The profile recording server can also provide access to traces over a UNIX domain socket. For more information, see <doc:ProfileRecorderServer/ProfileRecorderServer>.

## Topics

### Capturing Samples

- ``ProfileRecorderServer/ProfileRecorderServer``
- ``ProfileRecorderServer/ProfileRecorderServerConfiguration``
