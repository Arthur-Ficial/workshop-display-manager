// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LiquidGlassDemo",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "LiquidGlassDemo", path: "Sources/LiquidGlassDemo")
    ]
)
