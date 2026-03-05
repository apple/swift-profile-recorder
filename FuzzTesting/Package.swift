// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "FuzzTesting",
    platforms: [
        .macOS(.v11)
    ],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .target(
            name: "FuzzELF",
            dependencies: [
                .product(name: "_ProfileRecorderSampleConversion", package: "swift-profile-recorder")
            ]
        )
    ]
)
