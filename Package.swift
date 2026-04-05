// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HEIMDALLControlSurface",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "HEIMDALLControlSurface",
            targets: ["HEIMDALLControlSurface"]
        )
    ],
    targets: [
        .executableTarget(
            name: "HEIMDALLControlSurface",
            resources: [
                .process("../../Resources")
            ]
        ),
        .testTarget(
            name: "HEIMDALLControlSurfaceTests",
            dependencies: ["HEIMDALLControlSurface"]
        )
    ]
)
