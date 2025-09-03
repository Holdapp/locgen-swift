// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "locgen-swift",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX", .upToNextMajor(from: "0.14.1")),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.0.1")),
        .package(url: "https://github.com/jpsim/Yams", .upToNextMajor(from: "4.0.6"))
    ],
    targets: [
        .executableTarget(
            name: "locgen-swift",
            dependencies: [
                "CoreXLSX",
                "Yams",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .testTarget(
            name: "locgen-swiftTests",
            dependencies: ["locgen-swift"]),
    ]
)
