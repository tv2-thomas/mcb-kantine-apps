// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KantineBar",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "KantineBar", path: "Sources/KantineBar"),
    ]
)
