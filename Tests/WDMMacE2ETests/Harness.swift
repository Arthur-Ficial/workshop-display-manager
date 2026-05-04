import Foundation
@testable import WDMRemoteControl

/// Test harness for spawning `wdm-mac --remote --headless` against a
/// fixture display provider. Mirrors the WDMWeb test harness pattern.
struct E2EEnv {
    let dir: URL
    let fixture: URL
    let stateFile: URL
}

func makeEnv() throws -> E2EEnv {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("wdm-mac-e2e-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let fixture = dir.appendingPathComponent("fixture.json")
    try fixtureJSON.write(to: fixture, atomically: true, encoding: .utf8)
    return E2EEnv(
        dir: dir,
        fixture: fixture,
        stateFile: dir.appendingPathComponent("remote.json")
    )
}

private let fixtureJSON = """
{
  "snapshot": {
    "createdAt": 1700000000,
    "displays": [
      {
        "id": 1, "name": "Built-in", "isMain": true, "isOnline": true,
        "mirrorSource": null,
        "currentMode": { "width": 2560, "height": 1664, "refreshHz": 60 },
        "origin": { "x": 0, "y": 0 },
        "rotationDegrees": 0
      },
      {
        "id": 2, "name": "Projector", "isMain": false, "isOnline": true,
        "mirrorSource": null,
        "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
        "origin": { "x": 2560, "y": 0 },
        "rotationDegrees": 0
      }
    ]
  },
  "availableModes": {
    "1": [{ "width": 2560, "height": 1664, "refreshHz": 60 }],
    "2": [{ "width": 1920, "height": 1080, "refreshHz": 60 }]
  }
}
"""

func spawnHeadless(env: E2EEnv) throws -> Process {
    let binary = try resolveBinary()
    let proc = Process()
    proc.executableURL = binary
    proc.arguments = ["--remote", "--headless", "--state-file", env.stateFile.path]
    proc.environment = [
        "WDM_TEST_FIXTURE": env.fixture.path,
        "WDM_PROFILES_DIR": env.dir.appendingPathComponent("profiles").path,
        "HOME": env.dir.path,
        "PATH": "/usr/bin:/bin",
    ]
    let errPipe = Pipe()
    proc.standardOutput = FileHandle.nullDevice
    proc.standardError = errPipe
    try proc.run()
    // Tee stderr to test stderr so failures are diagnosable.
    errPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if !data.isEmpty { FileHandle.standardError.write(data) }
    }
    return proc
}

func resolveBinary() throws -> URL {
    if let override = ProcessInfo.processInfo.environment["WDM_MAC_BIN"] {
        return URL(fileURLWithPath: override)
    }
    // Walk up from this test bundle to find .build/<config>/wdm-mac.
    let bundle = Bundle(for: BundleAnchor.self).bundleURL
    var dir = bundle.deletingLastPathComponent()
    for _ in 0..<8 {
        let candidate = dir.appendingPathComponent("wdm-mac")
        if FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
        dir = dir.deletingLastPathComponent()
    }
    throw NSError(domain: "wdm-mac-e2e", code: 1,
                  userInfo: [NSLocalizedDescriptionKey: "could not locate wdm-mac binary"])
}

private final class BundleAnchor {}

func waitForPort(stateFile: URL, timeout: TimeInterval = 5.0) throws -> UInt16 {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let s = try? RemoteStateWriter.read(from: stateFile) {
            return s.port
        }
        Thread.sleep(forTimeInterval: 0.05)
    }
    throw NSError(domain: "wdm-mac-e2e", code: 2,
                  userInfo: [NSLocalizedDescriptionKey: "wdm-mac never wrote \(stateFile.path)"])
}

func get(_ url: URL) async throws -> Data {
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}
