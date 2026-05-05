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
            path: "Sources/WDMMac",
            resources: [
                // Bundled web resources for the embedded Stage canvas.
                // The Stage is the only WebKit-rendered surface in WDMMac;
                // the rest of the app stays 100% native SwiftUI / AppKit.
                .copy("Resources/stage")
            ],
            swiftSettings: [
                // Per-target deployment bump: WDMMac uses macOS 26 Liquid Glass
                // APIs (NSGlassEffectView, .glassEffect, .buttonStyle(.glass)).
                // Other libs (WDMCore, WDMKit, …) stay at the package's .v13.
                .unsafeFlags(["-target", "arm64-apple-macosx26.0"])
            ]
        ),
        .target(
            name: "WDMMacRemote",
            dependencies: ["WDMMac", "WDMRemoteControl"],
            path: "Sources/WDMMacRemote",
            swiftSettings: [
                .unsafeFlags(["-target", "arm64-apple-macosx26.0"])
            ]
        ),
        .executableTarget(
            name: "wdm-mac",
            dependencies: ["WDMMac", "WDMMacRemote"],
            path: "Sources/wdm-mac",
            swiftSettings: [
                // The binary's LC_BUILD_VERSION must say macOS 26 for the OS
                // to grant the launched app Liquid Glass chrome treatment.
                .unsafeFlags(["-target", "arm64-apple-macosx26.0"])
            ],
            linkerSettings: [
                .unsafeFlags(["-target", "arm64-apple-macosx26.0"])
            ]
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
            dependencies: ["WDMMacRemote", "WDMMac"],
            path: "Tests/WDMMacRemoteTests",
            swiftSettings: [
                // WDMMac is built for macOS 26 — the test target must match.
                .unsafeFlags(["-target", "arm64-apple-macosx26.0"])
            ]
        ),
        .testTarget(
            name: "WDMMacE2ETests",
            dependencies: ["WDMMac", "WDMMacRemote", "WDMRemoteControl"],
            path: "Tests/WDMMacE2ETests"
        ),
    ]
)
