import Foundation
@testable import WDMRemoteControl

/// Test harness for spawning `wdm-mac --remote --headless` against a
/// fixture display provider. Mirrors the WDMWeb test harness pattern.
struct E2EEnv {
    let dir: URL
    let fixture: URL
    let stateFile: URL
    var overlayLog: URL { dir.appendingPathComponent("overlay-flipper.log") }
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

/// Spawn variant that wires a flipper that throws on `run(...)` —
/// proves the GUI surfaces flip failures via inspector.geometry.lastError.
func spawnHeadlessWithFlipperThrow(env: E2EEnv, message: String) throws -> Process {
    let binary = try resolveBinary()
    let proc = Process()
    proc.executableURL = binary
    proc.arguments = ["--remote", "--headless", "--state-file", env.stateFile.path]
    proc.environment = [
        "WDM_TEST_FIXTURE": env.fixture.path,
        "WDM_PROFILES_DIR": env.dir.appendingPathComponent("profiles").path,
        "WDM_TEST_OVERLAY_LOG": env.overlayLog.path,
        "WDM_TEST_OVERLAY_THROW": message,
        "HOME": env.dir.path,
        "PATH": "/usr/bin:/bin",
    ]
    let errPipe = Pipe()
    proc.standardOutput = FileHandle.nullDevice
    proc.standardError = errPipe
    try proc.run()
    errPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if !data.isEmpty { FileHandle.standardError.write(data) }
    }
    return proc
}

func spawnHeadless(env: E2EEnv, extraEnv: [String: String] = [:]) throws -> Process {
    let binary = try resolveBinary()
    let proc = Process()
    proc.executableURL = binary
    proc.arguments = ["--remote", "--headless", "--state-file", env.stateFile.path]
    var environment: [String: String] = [
        "WDM_TEST_FIXTURE": env.fixture.path,
        "WDM_PROFILES_DIR": env.dir.appendingPathComponent("profiles").path,
        "WDM_TEST_OVERLAY_LOG": env.overlayLog.path,
        "HOME": env.dir.path,
        "PATH": "/usr/bin:/bin",
    ]
    for (k, v) in extraEnv { environment[k] = v }
    proc.environment = environment
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
    var lastPort: UInt16 = 0
    // Poll for the state file AND the HTTP listener accepting
    // connections. wdm-mac writes the state file slightly before its
    // network thread is ready to accept; without the second check, the
    // first /ui/snapshot request can hit a connection-refused race.
    while Date() < deadline {
        if let s = try? RemoteStateWriter.read(from: stateFile) {
            lastPort = s.port
            if isPortAccepting(port: s.port) {
                return s.port
            }
        }
        Thread.sleep(forTimeInterval: 0.05)
    }
    if lastPort != 0 {
        throw NSError(domain: "wdm-mac-e2e", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "wdm-mac wrote port \(lastPort) but never started accepting connections within \(timeout)s",
        ])
    }
    throw NSError(domain: "wdm-mac-e2e", code: 2,
                  userInfo: [NSLocalizedDescriptionKey: "wdm-mac never wrote \(stateFile.path)"])
}

/// Quick-probe: is anything actively accepting on 127.0.0.1:<port>?
/// Uses a short-timeout request to /ui/version which every wdm-mac
/// --remote serves; treat any HTTP response (even 404) as proof the
/// listener is up.
func isPortAccepting(port: UInt16) -> Bool {
    guard let url = URL(string: "http://127.0.0.1:\(port)/ui/version") else { return false }
    var req = URLRequest(url: url)
    req.timeoutInterval = 0.3
    let result = OkBox()
    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: req) { _, resp, _ in
        result.set((resp as? HTTPURLResponse) != nil)
        sem.signal()
    }.resume()
    _ = sem.wait(timeout: .now() + .milliseconds(400))
    return result.get()
}

private final class OkBox: @unchecked Sendable {
    private let lock = NSLock()
    private var v = false
    func set(_ b: Bool) { lock.withLock { v = b } }
    func get() -> Bool { lock.withLock { v } }
}

func get(_ url: URL) async throws -> Data {
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}
