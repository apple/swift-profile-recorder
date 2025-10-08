// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-profile-recorder",
    platforms: [
        // supported
        // Linux
        .macOS(.v11),

        // not supported, listed to make compilation work
        .iOS(.v14),
        .watchOS(.v7),
        .tvOS(.v14),
    ],
    products: [
        .library(name: "ProfileRecorder", targets: ["ProfileRecorder"]),
        .library(name: "ProfileRecorderServer", targets: ["ProfileRecorderServer"]),
        .library(name: "ProfileRecorderSampleConversion", targets: ["ProfileRecorderSampleConversion"]),
        .executable(name: "swipr-sample-conv", targets: ["swipr-sample-conv"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.80.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.24.1"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.2"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.25.2"),
    ],
    targets: [
        // MARK: - Executables
        .executableTarget(
            name: "swipr-mini-demo",
            dependencies: [
                "ProfileRecorder",
                "ProfileRecorderServer",
                "ProfileRecorderHelpers",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .target(
            name: "ProfileRecorderSampleConversion",
            dependencies: [
                "ProfileRecorder",
                "CProfileRecorderSwiftELF",
                "CProfileRecorderDarwin",
                "PprofFormat",
                "ProfileRecorderHelpers",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
            ]
        ),
        .executableTarget(
            name: "swipr-sample-conv",
            dependencies: [
                "CProfileRecorderSwiftELF",
                "ProfileRecorderSampleConversion",
                "ProfileRecorderHelpers",
                "ProfileRecorder",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        // MARK: - Library targets
        .target(
            name: "ProfileRecorder",
            dependencies: [
                "ProfileRecorderHelpers",
                .targetItem(
                    name: "CProfileRecorderSampler",
                    // We currently only support Linux but we compile just fine on macOS too.
                    // llvm unwind doesn't currently compile on watchOS, presumably because of arm64_32.
                    // Let's be a little conservative and allow-list macOS & Linux.
                    condition: .when(platforms: [.macOS, .linux])
                ),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "_NIOFileSystem", package: "swift-nio"),
            ]
        ),
        .target(
            name: "ProfileRecorderHelpers",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "_NIOFileSystem", package: "swift-nio"),
            ]
        ),
        .target(
            name: "PprofFormat",
            dependencies: [
                "ProfileRecorderHelpers",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
        .target(
            name: "ProfileRecorderServer",
            dependencies: [
                "ProfileRecorderHelpers",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "_NIOFileSystem", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                "ProfileRecorder",
                "ProfileRecorderSampleConversion",
                "PprofFormat",
            ]
        ),
        .target(
            name: "CProfileRecorderSwiftELF",
            dependencies: []
        ),
        .target(
            name: "CProfileRecorderDarwin",
            dependencies: []
        ),
        .target(
            name: "CProfileRecorderSampler",
            dependencies: []
        ),

        // MARK: - Tests
        .testTarget(
            name: "ProfileRecorderTests",
            dependencies: [
                "ProfileRecorder",
                "ProfileRecorderSampleConversion",
                "ProfileRecorderHelpers",
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "_NIOFileSystem", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "ProfileRecorderServerTests",
            dependencies: [
                "ProfileRecorder",
                "ProfileRecorderServer",
                "ProfileRecorderSampleConversion",
                "ProfileRecorderHelpers",
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "_NIOFileSystem", package: "swift-nio"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),
        .testTarget(
            name: "ProfileRecorderSampleConversionTests",
            dependencies: [
                "ProfileRecorder",
                "ProfileRecorderSampleConversion",
                "ProfileRecorderHelpers",
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "_NIOFileSystem", package: "swift-nio"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx14
)

for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(.enableExperimentalFeature("StrictConcurrency=complete"))
    target.swiftSettings = settings
}
