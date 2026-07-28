// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GHNCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GHNCore", targets: ["GHNCore"]),
    ],
    targets: [
        .target(name: "GHNCore"),
        .testTarget(name: "GHNCoreTests", dependencies: ["GHNCore"]),
    ]
)
