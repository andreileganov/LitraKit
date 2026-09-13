// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LitraKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "LitraKit",
            targets: ["LitraKit"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LitraKit"
        ),
        .testTarget(
            name: "LitraKitTests",
            dependencies: ["LitraKit"]
        )
    ]
)
