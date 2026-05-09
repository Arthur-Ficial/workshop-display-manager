import Testing
import Foundation
@testable import WDMRemoteControl

/// Drives Picture-in-Picture from the Inspector's Open PiP action. With
/// WDM_TEST_PIP_LOG set, the headless app uses RecordingPipFlipper —
/// clicking inspector.action.pip writes a `run source=… destination=…`
/// line to the log. Proves the click reaches WDMController.pip(plan:)
/// against the same primitive `wdm pip <id>` uses.
@Suite("wdm-mac headless: Inspector Open PiP flow", .serialized)
struct HeadlessPipTests {
    @Test func clickingPipWritesRunLine() async throws {
        let env = try makeEnv()
        let pipLog = env.dir.appendingPathComponent("pip.log")

        let proc = try spawnHeadless(env: env, extraEnv: [
            "WDM_TEST_PIP_LOG": pipLog.path
        ])
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        // Default selection is display 1 (Built-in main). Select display 2
        // first so the source/destination pair makes sense (PiP from
        // Projector → Built-in main).
        let tile2 = try await findRef(port: port, id: "displays.tile.2")
        try await postClick(port: port, ref: tile2)
        try await Task.sleep(nanoseconds: 200_000_000)

        let pipRef = try await findRef(port: port, id: "inspector.action.pip")
        try await postClick(port: port, ref: pipRef)

        try await waitForFileLine(url: pipLog, contains: "run source=2", timeoutMs: 2000)
        let log = (try? String(contentsOf: pipLog)) ?? ""
        #expect(log.contains("destination=1"),
                "expected destination=1 (built-in main); got log:\n\(log)")
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

    private func waitForFileLine(url: URL, contains needle: String, timeoutMs: Int) async throws {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            if let text = try? String(contentsOf: url),
               text.contains(needle) {
                return
            }
            try await Task.sleep(nanoseconds: 80_000_000)
        }
        Issue.record("waited \(timeoutMs)ms for '\(needle)' in \(url.path) but never appeared")
    }
}
