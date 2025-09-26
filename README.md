# Swift Profile Recorder, an in-process sampling profiler

Want to profile your software in restricted Kubernetes or Docker contrainers or other environments where you don't get `CAP_SYS_PTRACE`? Look no further.

## What is this?

This is a sampling profiler (like `sample` on macOS) with the special twist that it runs _inside_ the process that gets sampled. This means that it doesn't need `CAP_SYS_PTRACE` or any other privileges to work.

You can pull it in as a fully self-contained Swift Package Manger dependency and then use it for your app.

Swift Profile Recorder is an on- and off-CPU profiler which means that it records waiting threads (e.g. sleeps, locks, blocking system calls) as well as running (i.e. computing) threads.

### Supported OSes

At the moment, it only supports Linux and macOS.
It could also support operating systems but it's not implemented at this point in time.

## How can I use it?

### Via Swift Profile Recorder Server

The easiest way to use Swift Profile Recorder in your application is to make it run the Swift Profile Recorder Server.
This allows you to retrieve symbolicated samples with a single `curl` (or any other HTTP client) command.

#### Using the Sampling Server

##### One off setup to get your application ready for sampling

- Add a `swift-profile-recorder` dependency: `.package(url: "https://github.com/apple/swift-profile-recorder.git", .upToNextMinor(from: "0.3.0"))`
- Make your main `executableTarget` depend on `ProfileRecorderServer`: `.product(name: "ProfileRecorderServer", package: "swift-profile-recorder"),`
- Add the following few lines at the very beginning of your main function (`static func main()` or `func run()`):

```swift
import ProfileRecorderServer

[...]

@main
struct YourApp {
   func run() async throws {
       // Run `ProfileRecorderServer` in the background if enabled via environment variable. Ignore failures.
       //
       // Example:
       //   SWIPR_SAMPLING_SERVER_URL_PATTERN='unix:///tmp/my-app-samples-{PID}.sock' ./my-app
       async let _ = { [logger] in
           do {
               try await ProfileRecorderServer(configuration: .parseFromEnvironment()).run(logger: logger)
           } catch {
               logger.warning(
                   "could not run profile recording server, continuing regardless",
                   metadata: ["error": "\(error)"]
               )
           }
       }()

       [... your regular main function ...]
    }
}
```

##### Using the profiling server

Once you added the profile recorder server to your app, you can enable it using an environment variable (assuming you passed `configuration: .parseFromEnvironment()`):

```bash
# Request the sampling server to listen on a UNIX Domain Socket at path `/tmp/my-app-samples-{PID}.sock`.
# `{PID}` will automatically be replaced with your process's process ID.
SWIPR_SAMPLING_SERVER_URL_PATTERN=unix:///tmp/my-app-samples-{PID}.sock .build/release/MyApp
```

After that, you're ready to request samples:

```bash
curl --unix-socket /tmp/my-app-samples-62012.sock -sd '{"numberOfSamples":10,"timeInterval":"100 ms"}' http://localhost/sample | swift demangle --compact > /tmp/samples.perf
```

Now, a file called `/tmp/samples.perf` should have been created. This file is in the standard Linux perf format.

#### Visualisation

Whilst `.perf` files are plain text files, they most easily digested in a visual form such as FlameGraphs.

Here are some common, relatively easy-to-use visualisation tools:

- [Speedscope](https://speedscope.app) ([speedscope.app](https://speedscope.app)), simply drag a `.perf` file (such as `/tmp/samples.perf` in the example above) onto the Speedscope website.
- [Firefox Profiler](https://profiler.firefox.com) ([profiler.firefox.com](https://profiler.firefox.com)), simply drag a `.perf` file (such as `/tmp/samples.perf` in the example above) onto the Firefox Profiler website.
- The original [FlameGraph](https://github.com/brendangregg/Flamegraph) tooling. Try for example `./stackcollapse-perf.pl < /tmp/samples.perf | swift demangle --compact | ./flamegraph.pl > /tmp/samples.svg && open -a Safari /tmp/samples.svg`.
