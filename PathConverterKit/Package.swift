// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PathConverterKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "PathConverterKit",
            targets: ["PathConverterKit"]
        ),
    ],
    targets: [
        .target(
            name: "PathConverterKit",
            dependencies: []
        ),
        .testTarget(
            name: "PathConverterKitTests",
            dependencies: ["PathConverterKit"]
        ),
    ]
)