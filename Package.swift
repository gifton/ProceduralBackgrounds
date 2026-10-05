// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProceduralBackgrounds",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "BackgroundCore", targets: ["BackgroundCore"]),
        .library(name: "BackgroundUI", targets: ["BackgroundUI"])
    ],
    targets: [
        .target(name: "BackgroundCore"),
        .target(name: "BackgroundUI", dependencies: ["BackgroundCore"],
                resources: [.process("ShanShui/Shaders")]),
        .testTarget(name: "BackgroundCoreTests", dependencies: ["BackgroundCore"]),
        .testTarget(name: "BackgroundUITests", dependencies: ["BackgroundUI", "BackgroundCore"])
    ]
)
