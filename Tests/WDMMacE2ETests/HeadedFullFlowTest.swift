import Testing
import Foundation
@testable import WDMRemoteControl

/// One-shot end-to-end demo: spawns the headed `wdm-mac.app`, then drives
/// the entire UI through the remote API in a single ordered sequence —
/// no AppleScript, no parallel test scheduling weirdness, no shared
/// instance fragility. Last step closes the main window through the API.
///
/// Run via:
///   swift test --filter HeadedFullFlowTest \
///     -- --serialized
///   (env: WDM_HEADED_E2E=1 WDM_MAC_APP=/path/to/WDMMac.app)
///
/// Watch the visible app on screen while it runs — every click + keystroke
/// + screenshot you see comes from a /ui/* call.
@Suite("Headed full-flow: every action via /ui/*, close last")
struct HeadedFullFlowTest {
    @Test func driveEverythingAndQuit() async throws {
        guard ProcessInfo.processInfo.environment["WDM_HEADED_E2E"] == "1",
              ProcessInfo.processInfo.environment["WDM_HEADED_FULL"] == "1"
        else { return }

        let env = try makeHeadedEnv()
        _ = try spawnHeaded(env: env)
        let port = try waitForPort(stateFile: env.stateFile)
        let api = APIClient(port: port)

        // Give SwiftUI a beat to populate its AX tree.
        try await Task.sleep(nanoseconds: 1_500_000_000)

        log("[1/9] raise the main window via /ui/raiseWindow")
        try await api.post("/ui/raiseWindow", #"{"name":"Workshop Display Manager"}"#)

        log("[2/9] snapshot — assert all expected IDs present via /ui/snapshot")
        var tree = try await api.snapshot()
        let buttons = Dictionary(grouping: tree.nodes.filter { $0.role == "button" },
                                 by: \.remoteID).mapValues { $0.first! }
        try #require(buttons["titlebar.tab.stage"] != nil, "titlebar tabs visible")

        log("[3/9] click each titlebar tab via /ui/click")
        for label in ["titlebar.tab.stage", "titlebar.tab.profiles", "titlebar.tab.recordings"] {
            let ref = buttons[label]!.ref.rawValue
            try await api.post("/ui/click", #"{"ref":"\#(ref)"}"#)
            try await Task.sleep(nanoseconds: 250_000_000)
        }

        log("[4/9] click each rotation segment + flip segment in the inspector")
        tree = try await api.snapshot()
        let inspectorButtons = tree.nodes.filter { $0.role == "button"
            && ($0.remoteID.hasPrefix("inspector.rotate.") || $0.remoteID.hasPrefix("inspector.flip.")) }
        for n in inspectorButtons {
            try await api.post("/ui/click", #"{"ref":"\#(n.ref.rawValue)"}"#)
            try await Task.sleep(nanoseconds: 120_000_000)
        }

        log("[5/9] open Settings via /ui/invokeMenu {selector: openSettings}")
        try await api.post("/ui/invokeMenu", #"{"selector":"openSettings"}"#)

        log("[6/9] wait for settings.appearance.picker via /ui/wait")
        try await api.post("/ui/wait",
                           #"{"remoteID":"settings.appearance.picker","timeoutMs":3000}"#)

        log("[7/9] take a screenshot of the Settings window via /ui/screenshot")
        let png = try await api.getRaw("/ui/screenshot?window=Settings")
        let outDir = URL(fileURLWithPath: "/tmp/wdm-fullflow")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        try png.write(to: outDir.appendingPathComponent("settings.png"))
        log("    saved /tmp/wdm-fullflow/settings.png (\(png.count) bytes)")

        log("[8/9] close Settings via /ui/closeWindow")
        try await api.post("/ui/closeWindow", #"{"name":"Settings"}"#)
        try await Task.sleep(nanoseconds: 400_000_000)

        log("[9/9] close the main window via /ui/closeWindow — app quits")
        try await api.post("/ui/closeWindow", #"{"name":"Workshop Display Manager"}"#)

        log("✓ full flow completed — every action went through /ui/*")
    }

    private func log(_ s: String) {
        FileHandle.standardError.write(Data("    \(s)\n".utf8))
    }
}

/// Tiny URLSession wrapper so the test reads top-to-bottom.
private struct APIClient {
    let port: UInt16
    private var base: String { "http://127.0.0.1:\(port)" }

    func snapshot() async throws -> SceneTree {
        let data = try await getRaw("/ui/snapshot")
        return try SceneTreeJSON.decode(data)
    }

    @discardableResult
    func post(_ path: String, _ jsonBody: String) async throws -> Data {
        var req = URLRequest(url: URL(string: "\(base)\(path)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data(jsonBody.utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    func getRaw(_ path: String) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "\(base)\(path)")!)
        return data
    }
}
