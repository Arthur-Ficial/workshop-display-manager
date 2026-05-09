import Testing
import Foundation
@testable import WDMRemoteControl

/// Drives screen recording from the Inspector's Record action. With
/// WDM_TEST_RECORD_LOG set, the headless app uses RecordingRecorder —
/// clicking inspector.action.record writes a `record displayID=…
/// out=… durationSec=…` line to the log. Proves the click reaches the
/// same primitive `wdm record <id> --out <p> --duration <s>` uses.
@Suite("wdm-mac headless: Inspector Record flow", .serialized)
struct HeadlessRecordTests {
    @Test func clickingRecordWritesRecordLine() async throws {
        let env = try makeEnv()
        let recordLog = env.dir.appendingPathComponent("record.log")

        let proc = try spawnHeadless(env: env, extraEnv: [
            "WDM_TEST_RECORD_LOG": recordLog.path,
            "HOME": env.dir.path
        ])
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        let recRef = try await findRef(port: port, id: "inspector.action.record")
        try await postClick(port: port, ref: recRef)

        try await waitForFileLine(url: recordLog, contains: "record displayID=", timeoutMs: 3000)

        let log = (try? String(contentsOf: recordLog)) ?? ""
        #expect(log.contains("displayID=1"),
                "expected displayID=1 (default-selected); got log:\n\(log)")
        #expect(log.contains("durationSec=10"),
                "expected default 10s duration; got log:\n\(log)")
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
