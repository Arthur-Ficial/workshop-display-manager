// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "wdm",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "wdm", targets: ["wdm"]),
        .library(name: "WDMCore", targets: ["WDMCore"]),
        .library(name: "WDMSystem", targets: ["WDMSystem"]),
        .library(name: "WDMKit", targets: ["WDMKit"]),
        .library(name: "WDMCLI", targets: ["WDMCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.6"),
    ],
    targets: [
        .target(
            name: "WDMCore",
            path: "Sources/WDMCore"
        ),
        .target(
            name: "CGVirtualDisplaySPI",
            path: "Sources/CGVirtualDisplaySPI",
            publicHeadersPath: "include"
        ),
        .target(
            name: "WDMSystem",
            dependencies: ["WDMCore", "CGVirtualDisplaySPI"],
            path: "Sources/WDMSystem"
        ),
        .target(
            name: "WDMKit",
            dependencies: ["WDMCore", "WDMSystem"],
            path: "Sources/WDMKit"
        ),
        .target(
            name: "WDMCLI",
            dependencies: ["WDMCore", "WDMSystem", "WDMKit"],
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
