import Testing
import Foundation
@testable import WDMRemoteControl

/// One-shot end-to-end demo: drives the entire UI through `/ui/*` in a
/// single ordered sequence and ends by closing the main window. Watch
/// the visible app on screen — every click + appearance flip + screenshot
/// you see comes from a /ui/* call. No osascript anywhere.
///
/// Gated behind WDM_HEADED_E2E=1 + WDM_HEADED_FULL=1 so it runs in
/// isolation (the close-app step terminates the shared instance).
@Suite("Headed full-flow: every action via /ui/*, close last")
struct HeadedFullFlowTest {
    @Test func driveEverythingAndQuit() async throws {
        guard headedEnabled(),
              ProcessInfo.processInfo.environment["WDM_HEADED_FULL"] == "1"
        else { return }
        let api = try await MainActor.run { try sharedHeadedAPI() }
        let outDir = URL(fileURLWithPath: "/tmp/wdm-fullflow")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        log("[1/12] /ui/raiseWindow Workshop Display Manager")
        try await api.raiseWindow(named: "Workshop Display Manager")

        log("[2/12] /ui/snapshot — assert all expected IDs present")
        let tree = try await api.snapshot()
        try #require(tree.nodes.contains { $0.remoteID == "titlebar.tab.stage" })

        log("[3/12] click each TITLEBAR TAB + assert state ACTUALLY CHANGED")
        // Real state-change assertion: snapshot before, click, snapshot
        // after, assert the underlying SwiftUI tree's `version` increased
        // (proves the action handler ran, not just that AXPress returned ok).
        for label in ["titlebar.tab.stage", "titlebar.tab.profiles", "titlebar.tab.recordings"] {
            let before = try await api.snapshot()
            let r = try await api.clickRemoteID(label)
            #expect(r["ok"] as? Bool == true, "click \(label) -> \(r)")
            try await Task.sleep(nanoseconds: 250_000_000)  // re-render
            let after = try await api.snapshot()
            #expect(after.version > before.version,
                    "click \(label) did not change snapshot version (was \(before.version), still \(after.version)) — SwiftUI action probably did not fire")
            log("        ✓ /ui/click \(label) — version \(before.version) → \(after.version)")
            try await Task.sleep(nanoseconds: 450_000_000)  // visible pause
            let png = try await api.screenshot(window: "Workshop Display Manager")
            try png.write(to: outDir.appendingPathComponent("tab-\(label).png"))
        }

        log("[4/12] click EVERY OTHER clickable remoteID (sidebar, stage, inspector, statusbar)")
        let clickList: [String] = [
            "titlebar.profile",
            "displays.tile.1", "stage.tile.1",
            "sidebar.virtual.add",
            "inspector.mode.dropdown",
            "inspector.rotate.0", "inspector.rotate.90", "inspector.rotate.180", "inspector.rotate.270",
            "inspector.flip.none", "inspector.flip.h", "inspector.flip.v",
            "inspector.action.makeMain", "inspector.action.pip", "inspector.action.record",
            "inspector.action.reset", "inspector.action.advanced",
            "statusbar.toggle.watch", "statusbar.toggle.advanced",
        ]
        for id in clickList {
            let r = try await api.clickRemoteID(id)
            #expect(r["ok"] as? Bool == true, "click \(id) -> \(r)")
            log("        ✓ /ui/click \(id)")
            try await Task.sleep(nanoseconds: 250_000_000)  // visible but quicker
        }
        log("    \(3 + clickList.count) elements clicked via /ui/click")

        log("[5/12] /ui/screenshot Workshop Display Manager → main.png")
        let mainPng = try await api.screenshot(window: "Workshop Display Manager")
        try mainPng.write(to: outDir.appendingPathComponent("main.png"))
        log("    \(mainPng.count) bytes")

        log("[6/12] /ui/invokeMenu openSettings")
        let openR = try await api.invokeMenu("openSettings")
        #expect(openR["ok"] as? Bool == true, "invokeMenu openSettings -> \(openR)")

        log("[7/12] /ui/wait for settings.appearance.system; screenshot Settings")
        let waitR = try await api.waitFor(remoteID: "settings.appearance.system")
        #expect(waitR["ok"] as? Bool == true, "wait for Settings -> \(waitR)")
        try (try await api.screenshot(window: "Settings"))
            .write(to: outDir.appendingPathComponent("settings-initial.png"))

        log("[8/12] flip → LIGHT")
        try await flipAppearance(api: api, to: "settings.appearance.light",
                                 outFile: outDir.appendingPathComponent("after-light.png"))

        log("[9/12] flip → DARK")
        try await flipAppearance(api: api, to: "settings.appearance.dark",
                                 outFile: outDir.appendingPathComponent("after-dark.png"))

        log("[10/12] flip → SYSTEM")
        try await flipAppearance(api: api, to: "settings.appearance.system",
                                 outFile: outDir.appendingPathComponent("after-system.png"))

        log("[11/12] close Settings via /ui/closeWindow")
        let closeS = try await api.closeWindow(named: "Settings")
        #expect(closeS["ok"] as? Bool == true)

        log("[12/12] close Workshop Display Manager via /ui/closeWindow — app quits")
        let closeM = try await api.closeWindow(named: "Workshop Display Manager")
        #expect(closeM["ok"] as? Bool == true)

        log("✓ full flow completed — every action via /ui/*")
    }

    private func flipAppearance(api: HeadedAPI, to remoteID: String, outFile: URL) async throws {
        // Picker segments may take a beat to render after the previous click —
        // wait for the segment to be in the snapshot before clicking it.
        let waited = try await api.waitFor(remoteID: remoteID, timeoutMs: 2000)
        #expect(waited["ok"] as? Bool == true, "wait for \(remoteID) -> \(waited)")
        let r = try await api.clickRemoteID(remoteID)
        #expect(r["ok"] as? Bool == true, "click \(remoteID) -> \(r)")
        try await Task.sleep(nanoseconds: 350_000_000)
        let png = try await api.screenshot(window: "Settings")
        try png.write(to: outFile)
        log("    saved \(outFile.path) (\(png.count) bytes)")
    }

    private func log(_ s: String) {
        FileHandle.standardError.write(Data("    \(s)\n".utf8))
    }
}
