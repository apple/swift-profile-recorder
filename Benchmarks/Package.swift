// swift-tools-version:5.10
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "benchmarks",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.0"),
    ],
    targets: [
        .target(
            name: "SampleWorkload",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark")
            ],
            path: "Benchmarks/SampleWorkload",
        ),
        .executableTarget(
            name: "ConversionBenchmarks",
            dependencies: [
                "SampleWorkload",
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "ProfileRecorder", package: "swift-profile-recorder"),
                .product(name: "_ProfileRecorderSampleConversion", package: "swift-profile-recorder"),
            ],
            path: "Benchmarks/ConversionBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
    ]
)
