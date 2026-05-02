// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "wdm",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "wdm", targets: ["wdm"]),
        .library(name: "WDMCore", targets: ["WDMCore"]),
        .library(name: "WDMSystem", targets: ["WDMSystem"]),
        .library(name: "WDMCLI", targets: ["WDMCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "WDMCore",
            path: "Sources/WDMCore"
        ),
        .target(
            name: "WDMSystem",
            dependencies: ["WDMCore"],
            path: "Sources/WDMSystem"
        ),
        .target(
            name: "WDMCLI",
            dependencies: [
                "WDMCore",
                "WDMSystem",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/WDMCLI"
        ),
        .executableTarget(
            name: "wdm",
            dependencies: ["WDMCLI"],
            path: "Sources/wdm"
        ),
        .testTarget(
            name: "WDMCoreTests",
            dependencies: ["WDMCore"],
            path: "Tests/WDMCoreTests"
        ),
        .testTarget(
            name: "WDMSystemTests",
            dependencies: ["WDMCore", "WDMSystem"],
            path: "Tests/WDMSystemTests"
        ),
        .testTarget(
            name: "WDMCLITests",
            dependencies: ["WDMCore", "WDMSystem", "WDMCLI"],
            path: "Tests/WDMCLITests"
        ),
    ]
)
