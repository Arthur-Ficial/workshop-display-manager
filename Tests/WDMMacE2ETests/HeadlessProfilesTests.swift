import Testing
import Foundation
@testable import WDMRemoteControl

/// End-to-end: pre-seed two profiles on disk via `WDM_PROFILES_DIR`,
/// spawn `wdm-mac --remote --headless`, hit `GET /ui/snapshot`, assert
/// the sidebar's PROFILES section renders one button row per profile
/// with the stable `sidebar.profiles.row.<name>` remote ID. Closes the
/// SPEC.md gap "WDMMac frontend reaches feature parity with CLI for
/// read verbs" for `wdm profiles`.
@Suite("wdm-mac headless: sidebar PROFILES section reads live")
struct HeadlessProfilesTests {
    @Test func sidebarRendersOnePerProfile() async throws {
        let env = try makeEnv()
        try seedProfiles(["desk", "stage"], in: env)
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }

        let port = try waitForPort(stateFile: env.stateFile)
        let snap = try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        let tree = try SceneTreeJSON.decode(snap)

        let ids = Set(tree.nodes.map(\.remoteID))
        #expect(ids.contains("sidebar.profiles.row.desk"),
                "expected sidebar.profiles.row.desk among \(ids.sorted())")
        #expect(ids.contains("sidebar.profiles.row.stage"),
                "expected sidebar.profiles.row.stage among \(ids.sorted())")
        #expect(!ids.contains("sidebar.profiles.empty"),
                "empty hint should disappear once profiles exist")
    }

    @Test func sidebarShowsNoRowsWhenEmpty() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }

        let port = try waitForPort(stateFile: env.stateFile)
        let snap = try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        let tree = try SceneTreeJSON.decode(snap)

        let profileRowIDs = tree.nodes.map(\.remoteID)
            .filter { $0.hasPrefix("sidebar.profiles.row.") }
        #expect(profileRowIDs.isEmpty,
                "no profile rows must appear when none are saved; got \(profileRowIDs)")
    }

    /// Writes `<name>.json` for each name into env.dir/profiles/, with a
    /// minimal valid Snapshot body that ProfileStore.load can decode.
    private func seedProfiles(_ names: [String], in env: E2EEnv) throws {
        let dir = env.dir.appendingPathComponent("profiles")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let body = """
        {
          "createdAt": 1700000000,
          "displays": [
            {
              "id": 1, "name": "Built-in", "isMain": true, "isOnline": true,
              "mirrorSource": null,
              "currentMode": { "width": 2560, "height": 1664, "refreshHz": 60 },
              "origin": { "x": 0, "y": 0 },
              "rotationDegrees": 0
            }
          ]
        }
        """
        for name in names {
            try body.write(to: dir.appendingPathComponent("\(name).json"),
                           atomically: true, encoding: .utf8)
        }
    }
}
