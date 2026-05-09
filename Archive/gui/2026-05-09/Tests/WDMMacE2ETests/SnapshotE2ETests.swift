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

        // Each display surfaces TWICE on the agent surface — once as the
        // sidebar row (`displays.tile.X`) and once as the Stage tile
        // mirror (`stage.tile.X`). The Stage canvas is rendered in a
        // WKWebView whose DOM children aren't visible to the macOS
        // accessibility walker, so the registry carries the stage.tile.*
        // mirror for AI-controllability. Filter to display-related IDs so
        // future sidebar additions (PROFILES Save button, VIRTUAL +, etc.)
        // don't regress this test.
        let displayIDs = tree.nodes.map(\.remoteID).filter {
            $0.hasPrefix("displays.tile.") || $0.hasPrefix("stage.tile.")
        }
        #expect(displayIDs == ["displays.tile.1", "stage.tile.1",
                               "displays.tile.2", "stage.tile.2"])
        let displayLabels = tree.nodes
            .filter { $0.remoteID.hasPrefix("displays.tile.") || $0.remoteID.hasPrefix("stage.tile.") }
            .compactMap(\.label)
        #expect(displayLabels == ["Built-in", "Built-in", "Projector", "Projector"])
    }

    @Test func clickRoundTripsToSelectedState() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }

        let port = try waitForPort(stateFile: env.stateFile)
        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        req.httpMethod = "POST"
        // Click the Projector's sidebar row — index 3 now that every
        // display has both displays.tile.X and stage.tile.X entries.
        req.httpBody = Data(#"{"ref":"@e3"}"#.utf8)
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
