import Testing
import Foundation
@testable import WDMRemoteControl

/// Headed e2e — proves the titlebar tabs (Stage / Profiles / Recordings)
/// are clickable through `wdm-mac-control` / the remote API alone.
@Suite("Headed: titlebar tabs clickable through wdm-mac-control")
struct HeadedTabClickTests {
    @Test func tabsClickableViaRemoteAPI() async throws {
        guard headedEnabled() else { return }
        let api = try await MainActor.run { try sharedHeadedAPI() }
        for label in ["titlebar.tab.stage", "titlebar.tab.profiles", "titlebar.tab.recordings"] {
            let result = try await api.clickRemoteID(label)
            #expect(result["ok"] as? Bool == true,
                    "click \(label) returned \(result)")
        }
    }
}

struct HeadedEnv { let dir: URL; let stateFile: URL }

/// Stable test HOME so the state file always lands at the same path —
/// lets HeadedAppInstance reuse the same wdm-mac across `swift test`
/// invocations instead of relaunching every run.
func makeHeadedEnv() throws -> HeadedEnv {
    let dir = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".cache/wdm-headed-tests")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let configDir = dir.appendingPathComponent(".config/wdm")
    try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    return HeadedEnv(dir: dir, stateFile: configDir.appendingPathComponent("remote.json"))
}

/// Kill the wdm-mac process referenced by the state file.
func killHeaded(env: HeadedEnv) {
    if let data = try? Data(contentsOf: env.stateFile),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let pid = json["pid"] as? Int32 {
        kill(pid, SIGTERM)
    }
}

func spawnHeaded(env: HeadedEnv) throws -> Process {
    // Headed needs the .app bundle launched via `open` so LaunchServices
    // registers a proper session — without that, NSApp's menu bar
    // (Settings…, etc.) doesn't appear in the AX tree.
    //
    // `-n` forces a NEW instance even if WDMMac.app is already running.
    // Without it, `open -a` simply activates the existing instance and
    // silently DROPS the --args, so --state-file is never received and
    // waitForPort times out. Killing existing instances first is the
    // belt-and-braces partner; the test harness retains responsibility
    // for tearing down whatever it spawned.
    let app = ProcessInfo.processInfo.environment["WDM_MAC_APP"]
        ?? "\(FileManager.default.currentDirectoryPath)/.build/debug/WDMMac.app"
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    // `-n` forces a NEW instance + lets it coexist with any other
    // wdm-mac the user already has running (e.g. for manual testing).
    // Each instance has its own HOME-scoped state file, so the harness's
    // `HeadedAppInstance.shared()` always finds the right one. We do
    // NOT pkill the user's running instance from inside the test
    // harness — that's a global side-effect tests must not have.
    proc.arguments = ["-n", "-a", app, "--args", "--remote", "--state-file", env.stateFile.path]
    proc.environment = ["HOME": env.dir.path, "PATH": "/usr/bin:/bin"]
    proc.standardOutput = FileHandle.nullDevice
    proc.standardError = FileHandle.nullDevice
    try proc.run()
    proc.waitUntilExit()
    return proc
}
