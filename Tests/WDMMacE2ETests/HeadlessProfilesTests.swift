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
