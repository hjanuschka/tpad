// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TPad",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "TPadShared",
            targets: ["TPadShared"]
        ),
        .executable(
            name: "TPadServer",
            targets: ["TPadServer"]
        ),
    ],
    targets: [
        // Shared protocol and networking code
        .target(
            name: "TPadShared",
            path: "Shared"
        ),
        // macOS menu bar app
        .executableTarget(
            name: "TPadServer",
            dependencies: ["TPadShared"],
            path: "macOS"
        ),
    ]
)
