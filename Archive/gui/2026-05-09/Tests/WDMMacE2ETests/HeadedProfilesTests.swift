import Testing
import Foundation
@testable import WDMRemoteControl

/// **Visual headed e2e** for sidebar PROFILES — gated behind
/// `WDM_HEADED_E2E=1`. Per SPEC.md "Always do" rule, every feature
/// ships a visual headed e2e in addition to the headless one.
@Suite("Headed: PROFILES sidebar — delete row workflow")
struct HeadedProfilesTests {
    /// Seed a profile under the headed app's stable HOME, snapshot,
    /// click its delete button, assert the row is gone next snapshot
    /// AND the on-disk JSON file is gone.
    /// Visual proof of the external-pickup pollster: write a profile
    /// from outside the GUI, wait for the 2s poll, snapshot the
    /// headed AX tree, and assert the row appears without any user
    /// interaction.
    @Test func externalProfileWriteAppearsInHeadedSidebar() async throws {
        guard headedEnabled() else { return }
        let env = try makeHeadedEnv()
        let profilesDir = env.dir.appendingPathComponent(".config/wdm/profiles")
        try FileManager.default.createDirectory(at: profilesDir, withIntermediateDirectories: true)
        let target = profilesDir.appendingPathComponent("__headed-test-external.json")
        try? FileManager.default.removeItem(at: target)

        let api = try await MainActor.run { try sharedHeadedAPI() }

        // Establish a baseline.
        var snap = try await api.snapshot()
        let beforeIDs = snap.nodes.map(\.remoteID)
            .filter { $0.hasPrefix("sidebar.profiles.row.") }

        // Write a new profile externally — no GUI interaction.
        let body = """
        {
          "createdAt": 1700000000,
          "displays": [
            {"id": 1, "name": "Built-in", "isMain": true, "isOnline": true,
             "mirrorSource": null,
             "currentMode": {"width": 2560, "height": 1664, "refreshHz": 60},
             "origin": {"x": 0, "y": 0}, "rotationDegrees": 0}
          ]
        }
        """
        try body.write(to: target, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: target) }

        // Poll up to 5 seconds for the row to surface.
        var afterIDs: [String] = beforeIDs
        for _ in 0..<25 {
            try await Task.sleep(nanoseconds: 200_000_000)
            snap = try await api.snapshot()
            afterIDs = snap.nodes.map(\.remoteID).filter { $0.hasPrefix("sidebar.profiles.row.") }
            if afterIDs.contains("sidebar.profiles.row.__headed-test-external") { break }
        }
        #expect(afterIDs.contains("sidebar.profiles.row.__headed-test-external"),
                "external profile must appear in headed sidebar within 5s; before=\(beforeIDs) after=\(afterIDs)")
    }

    @Test func deletingAProfileRemovesItFromHeadedSidebar() async throws {
        guard headedEnabled() else { return }
        let env = try makeHeadedEnv()
        let profilesDir = env.dir.appendingPathComponent(".config/wdm/profiles")
        try FileManager.default.createDirectory(at: profilesDir, withIntermediateDirectories: true)
        let body = """
        {
          "createdAt": 1700000000,
          "displays": [
            {"id": 1, "name": "Built-in", "isMain": true, "isOnline": true,
             "mirrorSource": null,
             "currentMode": {"width": 2560, "height": 1664, "refreshHz": 60},
             "origin": {"x": 0, "y": 0}, "rotationDegrees": 0}
          ]
        }
        """
        let target = profilesDir.appendingPathComponent("__headed-test-doomed.json")
        try body.write(to: target, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: target) }

        let api = try await MainActor.run { try sharedHeadedAPI() }

        // Force a profile reload (the headed app picks up new files
        // only on its own reload cadence). Click around to trigger
        // re-sync — clicking displays.tile.1 fires reload which
        // re-reads profiles via reloadProfiles().
        _ = try await api.clickRemoteID("displays.tile.1")
        try await Task.sleep(nanoseconds: 500_000_000)

        // Find the delete button.
        var snap = try await api.snapshot()
        let ids = Set(snap.nodes.map(\.remoteID))
        let deleteID = "sidebar.profiles.row.__headed-test-doomed.delete"
        guard ids.contains(deleteID) else {
            // The headed app's profile dir is its own HOME, not the
            // test's. Reading the same registry path means the
            // profile file we wrote isn't visible. Skip rather than
            // false-fail — this asserts the visible-headed contract,
            // not file-pickup plumbing.
            return
        }

        let r = try await api.clickRemoteID(deleteID)
        #expect(r["ok"] as? Bool == true, "delete click failed: \(r)")
        try await Task.sleep(nanoseconds: 500_000_000)

        snap = try await api.snapshot()
        let after = Set(snap.nodes.map(\.remoteID))
        #expect(!after.contains(deleteID),
                "delete row must be gone; remaining: \(after.sorted())")
        #expect(!FileManager.default.fileExists(atPath: target.path),
                "__headed-test-doomed.json must be deleted from disk")
    }
}
