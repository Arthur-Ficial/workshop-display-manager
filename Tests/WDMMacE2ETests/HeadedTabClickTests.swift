import Testing
import Foundation
@testable import WDMRemoteControl

/// Headed e2e — proves the titlebar tabs (Stage / Profiles / Recordings)
/// are clickable through the remote API alone. Spawns the bundled .app
/// (NOT the headless binary — we need a real NSWindow + AXUIElement for
/// SwiftUI to expose its tree), snapshots, and verifies clicks.
///
/// Skipped automatically when WDM_HEADED_E2E != "1" so CI/headless runs
/// don't fail trying to open windows.
@Suite("Headed: titlebar tabs clickable through wdm-mac-control")
struct HeadedTabClickTests {
    @Test func tabsClickableViaRemoteAPI() async throws {
        guard ProcessInfo.processInfo.environment["WDM_HEADED_E2E"] == "1" else {
            return // opt-in only
        }
        let env = try makeHeadedEnv()
        let proc = try spawnHeaded(env: env)
        defer { proc.terminate() }

        let port = try waitForPort(stateFile: env.stateFile)
        // Wait a moment for the SwiftUI tree to populate.
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let snap = try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        let tree = try SceneTreeJSON.decode(snap)
        let tabRefs = ["Stage", "Profiles", "Recordings"].compactMap { label in
            tree.nodes.first { $0.role == "button" && $0.label == label }?.ref
        }
        #expect(tabRefs.count == 3)

        // Click each one; each must return ok:true.
        for ref in tabRefs {
            var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
            req.httpMethod = "POST"
            req.httpBody = Data(#"{"ref":"\#(ref.rawValue)"}"#.utf8)
            let (data, _) = try await URLSession.shared.data(for: req)
            let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(result?["ok"] as? Bool == true,
                    "click \(ref.rawValue) (a titlebar tab) returned \(result ?? [:])")
        }
    }
}

struct HeadedEnv { let dir: URL; let stateFile: URL }

func makeHeadedEnv() throws -> HeadedEnv {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("wdm-headed-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return HeadedEnv(dir: dir, stateFile: dir.appendingPathComponent("remote.json"))
}

func spawnHeaded(env: HeadedEnv) throws -> Process {
    // Headed needs the .app bundle so macOS gives it a real window.
    let app = ProcessInfo.processInfo.environment["WDM_MAC_APP"]
        ?? "\(FileManager.default.currentDirectoryPath)/.build/debug/WDMMac.app"
    let exe = URL(fileURLWithPath: app).appendingPathComponent("Contents/MacOS/wdm-mac")
    let proc = Process()
    proc.executableURL = exe
    proc.arguments = ["--remote", "--state-file", env.stateFile.path]
    proc.environment = ["HOME": env.dir.path, "PATH": "/usr/bin:/bin"]
    proc.standardOutput = FileHandle.nullDevice
    proc.standardError = FileHandle.nullDevice
    try proc.run()
    return proc
}
