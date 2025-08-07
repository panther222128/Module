// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Modules",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "NetworkService",
            targets: ["NetworkService"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NetworkService",
            path: "Sources/NetworkService"
        )
    ]
)
