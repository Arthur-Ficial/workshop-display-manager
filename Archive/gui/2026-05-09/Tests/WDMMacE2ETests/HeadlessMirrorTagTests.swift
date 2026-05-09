import Testing
import Foundation
@testable import WDMRemoteControl

/// Inspector HEADER's mirror tag — closes one design-briefing
/// status-tag item ("Mirror of 0X"). When a display is mirroring
/// another, the registry surfaces a passive `inspector.title.mirror`
/// node carrying "Mirror of <NN>" where NN is the source display's
/// 1-based index. Selecting an unmirrored display surfaces no such
/// node.
@Suite("wdm-mac headless: Inspector HEADER mirror-of tag")
struct HeadlessMirrorTagTests {
    @Test func mirrorTagAppearsForMirroredDisplay() async throws {
        let env = try makeEnv()
        try seedFixtureWithMirror(env: env, mirrorOf: 1, victim: 2)
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        // Click display 2 (the mirroring one) so it's the selected tile.
        let snap1 = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let tile2 = snap1.nodes.first { $0.remoteID == "displays.tile.2" }
        try #require(tile2 != nil)
        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(tile2!.ref.rawValue)"}"#.utf8)
        _ = try await URLSession.shared.data(for: click)
        try await Task.sleep(nanoseconds: 200_000_000)

        let snap2 = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let tag = snap2.nodes.first { $0.remoteID == "inspector.title.mirror" }
        try #require(tag != nil,
                     "expected inspector.title.mirror; got \(snap2.nodes.map(\.remoteID).sorted())")
        #expect(tag?.value?.contains("Mirror of") == true,
                "expected 'Mirror of …'; got \(String(describing: tag?.value))")
        #expect(tag?.value?.contains("01") == true,
                "expected source index '01'; got \(String(describing: tag?.value))")
    }

    @Test func noMirrorTagWhenIndependent() async throws {
        let env = try makeEnv()
        // Default fixture has no mirroring. Display 1 is selected by default.
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        let snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        #expect(snap.nodes.first { $0.remoteID == "inspector.title.mirror" } == nil,
                "no inspector.title.mirror should appear for an unmirrored display; got \(snap.nodes.map(\.remoteID).sorted())")
    }

    /// Rewrites the existing fixture so display `victim` mirrors display `source`.
    private func seedFixtureWithMirror(env: E2EEnv, mirrorOf source: Int, victim: Int) throws {
        let bytes = try Data(contentsOf: env.fixture)
        guard var obj = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let snap = obj["snapshot"] as? [String: Any],
              var displays = snap["displays"] as? [[String: Any]] else {
            return
        }
        for i in 0..<displays.count {
            if (displays[i]["id"] as? Int) == victim {
                displays[i]["mirrorSource"] = source
            }
        }
        var newSnap = snap
        newSnap["displays"] = displays
        obj["snapshot"] = newSnap
        let out = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted])
        try out.write(to: env.fixture, options: .atomic)
    }
}
