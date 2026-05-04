import Testing
import Foundation
@testable import WDMRemoteControl

/// First-milestone e2e: spawn the actual `wdm-mac --remote --headless` binary
/// against `WDM_TEST_FIXTURE`, hit `GET /ui/snapshot`, assert the displays
/// from the fixture come back through the remote API. This is the "AI sees
/// the UI" half of the milestone. The "AI clicks" half is exercised by the
/// `clickRoundTrip` test below.
@Suite("wdm-mac --remote --headless end-to-end")
struct WDMMacE2ETests {
    @Test func snapshotShowsFixtureDisplays() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }

        let port = try waitForPort(stateFile: env.stateFile)
        let snap = try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        let tree = try SceneTreeJSON.decode(snap)

        #expect(tree.nodes.count == 2)
        let labels = tree.nodes.compactMap(\.label)
        #expect(labels == ["Built-in", "Projector"])
        let remoteIDs = tree.nodes.map(\.remoteID)
        #expect(remoteIDs == ["displays.tile.1", "displays.tile.2"])
    }

    @Test func clickRoundTripsToSelectedState() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }

        let port = try waitForPort(stateFile: env.stateFile)
        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        req.httpMethod = "POST"
        req.httpBody = Data(#"{"ref":"@e2"}"#.utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(result?["ok"] as? Bool == true)

        // Wait briefly, then snapshot — the second tile should now be selected.
        try await Task.sleep(nanoseconds: 200_000_000)
        let snap = try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        let tree = try SceneTreeJSON.decode(snap)
        let projector = tree.nodes.first { $0.remoteID == "displays.tile.2" }
        #expect(projector?.state.selected == true)
    }
}
