// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Notic",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NoticCore", targets: ["NoticCore"]),
    ],
    targets: [
        .target(
            name: "NoticCore",
            swiftSettings: [
                .defaultIsolation(MainActor.self),
            ]
        ),
        .testTarget(
            name: "NoticCoreTests",
            dependencies: ["NoticCore"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
            ]
        ),
    ]
)
