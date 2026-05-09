import Testing
import Foundation
@testable import WDMRemoteControl

@Suite("WDMRemoteControl unit + server round-trip")
struct WDMRemoteControlSmokeTests {
    @Test func refRoundTrips() throws {
        let r = Ref(index: 42)
        #expect(r.rawValue == "@e42")
        #expect(Ref("@e42") == r)
        #expect(Ref("nope") == nil)
    }

    @Test func snapshotJSONRoundTrip() throws {
        let tree = SceneTree(version: 7, nodes: [
            SceneNode(ref: Ref(index: 1), remoteID: "a", role: "button", label: "Hi")
        ])
        let data = try SceneTreeJSON.encode(tree)
        let back = try SceneTreeJSON.decode(data)
        #expect(back == tree)
    }

    @Test func actionDecodeClick() throws {
        let body = Data(#"{"action":"click","ref":"@e3"}"#.utf8)
        let action = try RemoteActionJSON.decode(body)
        if case .click(let ref) = action {
            #expect(ref == Ref(index: 3))
        } else {
            Issue.record("expected click action")
        }
    }

    @Test func serverSnapshotAndClickRoundTrip() async throws {
        let fx = FixtureRemoteControllable(nodes: [
            SceneNode(ref: Ref(index: 1), remoteID: "displays.tile.1",
                      role: "button", label: "Built-in"),
            SceneNode(ref: Ref(index: 2), remoteID: "displays.tile.2",
                      role: "button", label: "Projector"),
        ])
        let port = try TestPort.findFree()
        let server = try RemoteControlServer(port: port, target: fx)
        server.runAsync()
        defer { server.stop() }
        try await Task.sleep(nanoseconds: 100_000_000)

        let snapURL = URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!
        let (snapData, snapResp) = try await URLSession.shared.data(from: snapURL)
        #expect((snapResp as? HTTPURLResponse)?.statusCode == 200)
        let tree = try SceneTreeJSON.decode(snapData)
        #expect(tree.nodes.count == 2)
        #expect(tree.nodes.map(\.label) == ["Built-in", "Projector"])

        var clickReq = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        clickReq.httpMethod = "POST"
        clickReq.httpBody = Data(#"{"ref":"@e2"}"#.utf8)
        let (clickData, clickResp) = try await URLSession.shared.data(for: clickReq)
        #expect((clickResp as? HTTPURLResponse)?.statusCode == 200)
        let resultJSON = try JSONSerialization.jsonObject(with: clickData) as? [String: Any]
        #expect(resultJSON?["ok"] as? Bool == true)
        #expect(fx.clicks[Ref(index: 2)] == 1)
    }
}
