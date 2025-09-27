# ``ProfileRecorderServer/ProfileRecorderServer``

## Overview

### Installing the Swift Profile Recorder Server

The Swift Profile Recorder Server is easy to integrate into your application.
First, add a dependency on ProfileRecorder:

```swift
    .package(url: "https://github.com/apple/swift-profile-recorder.git", .upToNextMinor(from: 0.3.0)),

    [...]

    .product(name: "ProfileRecorderServer", package: "swipr"),
```

Within your app, configure and run a profile recording server, for example:

```swift
import ProfileRecorderServer

await ProfileRecorderServer(
    configuration: try await .parseFromEnvironment()
).runIgnoringFailures(logger: logger)
```

The `parseFromEnvironment()` function parses the `PROFILE_RECORDER_SERVER_URL` & `PROFILE_RECORDER_SERVER_URL_PATTERN`
environment variables to configure the service.
If you prefer to statically configure it, use:

```swift
var profilingServerConfig = ProfileRecorderServerConfiguration.default
profilingServerConfig.bindTarget = try SocketAddress(ipAddress: "127.0.0.0", port: 7377)
try await ProfileRecorderServer(configuration: profilingServerConfig).run(logger: logger)
```

### Production Configuration

In production, it might be useful to use a UNIX Domain Socket instead of an HTTP server.
If you have access to the filesystem where your app runs, such as a shell in a virtual machine or shell access to a restricted Kubernetes or Docker contrainersrentes pod, use the environment variable `PROFILE_RECORDER_SERVER_URL_PATTERN` to define a UNIX domain socket to provide the traces.

For example, set `PROFILE_RECORDER_SERVER_URL_PATTERN="unix:///var/run/swipr-pid-{PID}.sock"`, and Swift Profile Recorder replaces the `{PID}` with the process id from your running app.
In containerised environments, you get files called `/var/run/swipr-pid-1.sock` from this pattern that you can sample using the following command:

```bash
curl -sd '{"numberOfSamples":100,"timeInterval":"10 ms"}' --unix-socket /var/run/swipr/pid-1.sock http://localhost | \
    swift demangle --simplified > /tmp/samples.perf
```

Drag the resulting file into [Firefox Profiler](https://profiler.firefox.com), a client-side web app, to see a visualization of the traces. 

## Topics

### Creating a profile recording server

- ``init(configuration:)``
- ``ProfileRecorderServerConfiguration``

### Inspecting the profile recording server

- ``configuration``

### Running the profile recording server

- ``run(logger:)``
- ``runIgnoringFailures(logger:)``
- ``withProfileRecordingServer(logger:_:)``
- ``ServerInfo``

