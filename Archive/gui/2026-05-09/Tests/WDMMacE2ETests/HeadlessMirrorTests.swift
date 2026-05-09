import Testing
import Foundation
@testable import WDMRemoteControl

/// Drives the Inspector's Mirror onto main action. With the fixture
/// provider, clicking inspector.action.mirror on display 2 should set
/// the fixture's display 2 mirrorSource to 1 (Built-in is main).
@Suite("wdm-mac headless: Inspector Mirror flow", .serialized)
struct HeadlessMirrorTests {
    @Test func clickingMirrorOntoMainSetsMirrorSourceInFixture() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        // Select display 2 (Projector) so the mirror action targets it.
        let tile2 = try await findRef(port: port, id: "displays.tile.2")
        try await postClick(port: port, ref: tile2)
        try await Task.sleep(nanoseconds: 200_000_000)

        let mirrorRef = try await findRef(port: port, id: "inspector.action.mirror")
        try await postClick(port: port, ref: mirrorRef)
        try await Task.sleep(nanoseconds: 400_000_000)

        // The fixture is the system of record. Read it directly.
        let bytes = try Data(contentsOf: env.fixture)
        let obj = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        let displays = (obj?["snapshot"] as? [String: Any])?["displays"] as? [[String: Any]]
        let projector = displays?.first { ($0["id"] as? Int) == 2 }
        let mirrorSrc = projector?["mirrorSource"] as? Int
        #expect(mirrorSrc == 1,
                "expected mirrorSource=1 (Built-in main); got \(String(describing: mirrorSrc))")
    }

    private func findRef(port: UInt16, id: String) async throws -> Ref {
        let snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let node = snap.nodes.first { $0.remoteID == id }
        try #require(node != nil, "\(id) must exist; got \(snap.nodes.map(\.remoteID).sorted())")
        return node!.ref
    }

    private func postClick(port: UInt16, ref: Ref) async throws {
        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(ref.rawValue)"}"#.utf8)
        let (_, resp) = try await URLSession.shared.data(for: click)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
    }
}
