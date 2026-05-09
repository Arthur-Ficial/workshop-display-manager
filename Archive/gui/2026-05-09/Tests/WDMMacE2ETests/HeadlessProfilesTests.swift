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

    /// Workshop facilitator's flagship use: click a profile row, the fixture
    /// state mutates to match the profile's arrangement. Closes the SPEC.md
    /// objective "facilitator can save a profile, hot-swap displays during
    /// a session, and `wdm restore` returns them to a known-good layout."
    @Test func clickingProfileRowRestoresArrangement() async throws {
        let env = try makeEnv()
        // Profile that moves Built-in to x=1000 (fixture's default is 0).
        try seedShiftedProfile(name: "off-stage", originX: 1000, in: env)

        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        // Find the profile row's ref via /ui/snapshot.
        let snap = try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        let tree = try SceneTreeJSON.decode(snap)
        let row = tree.nodes.first { $0.remoteID == "sidebar.profiles.row.off-stage" }
        try #require(row != nil, "profile row must exist")

        // Click it.
        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(row!.ref.rawValue)"}"#.utf8)
        let (data, resp) = try await URLSession.shared.data(for: click)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(result?["ok"] as? Bool == true)

        // Allow restore to complete (provider persist + reload).
        try await Task.sleep(nanoseconds: 300_000_000)

        // Fixture file is the system of record — assert display 1's origin moved.
        let fixtureBytes = try Data(contentsOf: env.fixture)
        let fixtureObj = try JSONSerialization.jsonObject(with: fixtureBytes) as? [String: Any]
        let snapshot = fixtureObj?["snapshot"] as? [String: Any]
        let displays = snapshot?["displays"] as? [[String: Any]]
        let builtIn = displays?.first { ($0["id"] as? Int) == 1 }
        let origin = builtIn?["origin"] as? [String: Int]
        #expect(origin?["x"] == 1000,
                "Built-in origin.x should be 1000 after restore; got \(String(describing: origin))")
    }

    /// Clicking the `+` in the PROFILES section header saves the current
    /// arrangement as a fresh profile (named "snapshot-<timestamp>") and
    /// re-renders the sidebar so the new row appears immediately.
    @Test func clickingProfilesAddSavesCurrentArrangement() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        // Find the add button.
        var snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let addBtn = snap.nodes.first { $0.remoteID == "sidebar.profiles.add" }
        try #require(addBtn != nil, "sidebar.profiles.add must exist")

        // Click it.
        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(addBtn!.ref.rawValue)"}"#.utf8)
        let (_, resp) = try await URLSession.shared.data(for: click)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
        try await Task.sleep(nanoseconds: 300_000_000)

        // A snapshot-* file should exist on disk and a matching row in the snapshot.
        let dir = env.dir.appendingPathComponent("profiles")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let savedJSONs = files.filter { $0.hasPrefix("snapshot-") && $0.hasSuffix(".json") }
        #expect(!savedJSONs.isEmpty, "expected one snapshot-*.json on disk; got \(files)")

        snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let rowIDs = snap.nodes.map(\.remoteID)
            .filter { $0.hasPrefix("sidebar.profiles.row.snapshot-") }
        #expect(!rowIDs.isEmpty, "expected a sidebar.profiles.row.snapshot-* entry; got \(snap.nodes.map(\.remoteID))")
    }

    /// External-change pickup: if `wdm save foo` runs in another
    /// terminal during a session, the GUI's PROFILES sidebar must
    /// catch up within a few seconds without any GUI interaction.
    /// Pollster lives inside MacRuntime; this test proves it works.
    @Test func externalProfileWriteAppearsInSidebar() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        // Initial: no profiles.
        var snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let beforeIDs = snap.nodes.map(\.remoteID).filter { $0.hasPrefix("sidebar.profiles.row.") }
        try #require(beforeIDs.isEmpty, "expected no rows initially; got \(beforeIDs)")

        // Externally write a profile (simulates `wdm save` in another terminal).
        try seedProfiles(["external"], in: env)

        // Poll the snapshot for up to 5 seconds for the row to appear.
        var afterIDs: [String] = []
        for _ in 0..<25 {
            try await Task.sleep(nanoseconds: 200_000_000)
            snap = try SceneTreeJSON.decode(
                try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
            )
            afterIDs = snap.nodes.map(\.remoteID).filter { $0.hasPrefix("sidebar.profiles.row.") }
            if afterIDs.contains("sidebar.profiles.row.external") { break }
        }
        #expect(afterIDs.contains("sidebar.profiles.row.external"),
                "external profile must appear within 5s; got \(afterIDs)")
    }

    /// Workshop facilitator cleanup: clicking the per-row `× delete`
    /// button removes the profile JSON from disk and from the sidebar.
    /// Same Kit op the CLI's `wdm profiles remove <name>` exposes.
    @Test func clickingProfileRowDeleteRemovesIt() async throws {
        let env = try makeEnv()
        try seedProfiles(["keep", "doomed"], in: env)

        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        var snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let deleteBtn = snap.nodes.first { $0.remoteID == "sidebar.profiles.row.doomed.delete" }
        try #require(deleteBtn != nil, "delete button must exist; ids=\(snap.nodes.map(\.remoteID).sorted())")

        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(deleteBtn!.ref.rawValue)"}"#.utf8)
        let (_, resp) = try await URLSession.shared.data(for: click)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
        try await Task.sleep(nanoseconds: 300_000_000)

        // On-disk file is gone.
        let dir = env.dir.appendingPathComponent("profiles")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        #expect(!files.contains("doomed.json"),
                "doomed.json must be deleted; remaining: \(files)")
        #expect(files.contains("keep.json"),
                "keep.json must survive; remaining: \(files)")

        // Snapshot refreshed: row gone, but the kept one survives.
        snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let ids = Set(snap.nodes.map(\.remoteID))
        #expect(!ids.contains("sidebar.profiles.row.doomed"),
                "doomed row must be gone")
        #expect(!ids.contains("sidebar.profiles.row.doomed.delete"),
                "doomed delete button must be gone")
        #expect(ids.contains("sidebar.profiles.row.keep"),
                "keep row must survive")
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

    /// Single profile whose Built-in display is shifted along X from the
    /// fixture's default (0,0). Used to verify restore mutates real state.
    private func seedShiftedProfile(name: String, originX: Int, in env: E2EEnv) throws {
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
              "origin": { "x": \(originX), "y": 0 },
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
        }
        """
        try body.write(to: dir.appendingPathComponent("\(name).json"),
                       atomically: true, encoding: .utf8)
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
