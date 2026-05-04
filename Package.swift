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
        .library(name: "WDMWeb", targets: ["WDMWeb"]),
        .executable(name: "wdm-web", targets: ["wdm-web"]),
        .library(name: "WDMRemoteControl", targets: ["WDMRemoteControl"]),
        .library(name: "WDMMac", targets: ["WDMMac"]),
        .library(name: "WDMMacRemote", targets: ["WDMMacRemote"]),
        .executable(name: "wdm-mac", targets: ["wdm-mac"]),
        .executable(name: "wdm-mac-control", targets: ["wdm-mac-control"]),
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
        .target(
            name: "WDMWeb",
            dependencies: ["WDMKit"],
            path: "Sources/WDMWeb"
        ),
        .executableTarget(
            name: "wdm-web",
            dependencies: ["WDMWeb"],
            path: "Sources/wdm-web"
        ),
        .target(
            name: "WDMRemoteControl",
            dependencies: ["WDMKit"],
            path: "Sources/WDMRemoteControl"
        ),
        .target(
            name: "WDMMac",
            dependencies: ["WDMKit"],
            path: "Sources/WDMMac"
        ),
        .target(
            name: "WDMMacRemote",
            dependencies: ["WDMMac", "WDMRemoteControl"],
            path: "Sources/WDMMacRemote"
        ),
        .executableTarget(
            name: "wdm-mac",
            dependencies: ["WDMMac", "WDMMacRemote"],
            path: "Sources/wdm-mac"
        ),
        .executableTarget(
            name: "wdm-mac-control",
            dependencies: ["WDMRemoteControl"],
            path: "Sources/wdm-mac-control"
        ),
        .testTarget(
            name: "WDMWebTests",
            dependencies: ["WDMWeb"],
            path: "Tests/WDMWebTests"
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
            name: "WDMKitTests",
            dependencies: ["WDMCore", "WDMSystem", "WDMKit"],
            path: "Tests/WDMKitTests"
        ),
        .testTarget(
            name: "WDMCLITests",
            dependencies: ["WDMCore", "WDMSystem", "WDMCLI"],
            path: "Tests/WDMCLITests"
        ),
        .testTarget(
            name: "WDMRemoteControlTests",
            dependencies: ["WDMRemoteControl"],
            path: "Tests/WDMRemoteControlTests"
        ),
        .testTarget(
            name: "WDMMacRemoteTests",
            dependencies: ["WDMMacRemote"],
            path: "Tests/WDMMacRemoteTests"
        ),
        .testTarget(
            name: "WDMMacE2ETests",
            dependencies: ["WDMMac", "WDMMacRemote", "WDMRemoteControl"],
            path: "Tests/WDMMacE2ETests"
        ),
    ]
)
