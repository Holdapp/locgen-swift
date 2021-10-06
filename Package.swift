// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "locgen-swift",
    dependencies: [
        .package(name: "CoreXLSX", url: "https://github.com/CoreOffice/CoreXLSX", .upToNextMajor(from: "0.14.1"))
    ],
    targets: [
        .executableTarget(
            name: "locgen-swift",
            dependencies: []),
        .testTarget(
            name: "locgen-swiftTests",
            dependencies: ["locgen-swift"]),
    ]
)
