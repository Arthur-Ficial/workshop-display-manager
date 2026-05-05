import Testing
import Foundation
@testable import WDMRemoteControl

@Suite("wdm-mac perf: remote interaction budget")
struct PerfBudgetTests {
    @Test func profileClickToSnapshotRoundTripStaysUnder100ms() async throws {
        let env = try makeEnv()
        try seedShiftedProfile(name: "snap-fast", originX: 1000, in: env)
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        let before = try await snapshot(port: port)
        let row = before.nodes.first { $0.remoteID == "sidebar.profiles.row.snap-fast" }
        try #require(row != nil, "profile row must exist")

        let started = Date()
        try await click(ref: row!.ref, port: port)
        let after = try await snapshot(port: port)
        let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
        let originX = try displayOriginX(displayID: 1, in: env)

        #expect(after.version > before.version,
                "/ui/click -> /ui/snapshot must observe a state change immediately")
        #expect(originX == 1000,
                "/ui/click must not return before profile restore persists; got x=\(String(describing: originX))")
        #expect(elapsedMs <= 100,
                "/ui/click -> /ui/snapshot took \(elapsedMs)ms; budget is 100ms")
    }

    private func snapshot(port: UInt16) async throws -> SceneTree {
        try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
    }

    private func click(ref: Ref, port: UInt16) async throws {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        request.httpMethod = "POST"
        request.httpBody = Data(#"{"ref":"\#(ref.rawValue)"}"#.utf8)
        let (_, response) = try await URLSession.shared.data(for: request)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }

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

    private func displayOriginX(displayID: Int, in env: E2EEnv) throws -> Int? {
        let fixtureBytes = try Data(contentsOf: env.fixture)
        let fixtureObj = try JSONSerialization.jsonObject(with: fixtureBytes) as? [String: Any]
        let snapshot = fixtureObj?["snapshot"] as? [String: Any]
        let displays = snapshot?["displays"] as? [[String: Any]]
        let display = displays?.first { ($0["id"] as? Int) == displayID }
        let origin = display?["origin"] as? [String: Int]
        return origin?["x"]
    }
}
