import Testing
import Foundation
@testable import WDMRemoteControl

/// Drives the Inspector's Reset / reconnect action. With
/// WDM_TEST_CAPTURE_LOG set, the headless app uses
/// RecordingDisplayCapturer — clicking inspector.action.reset writes
/// `capture id=…` and `release id=…` lines to the log. Proves the
/// click reaches WDMController.disconnectDisplay against the same
/// primitive `wdm doctor disconnect <id>` uses.
@Suite("wdm-mac headless: Inspector Reset flow", .serialized)
struct HeadlessResetTests {
    @Test func clickingResetWritesCaptureRelease() async throws {
        let env = try makeEnv()
        let captureLog = env.dir.appendingPathComponent("capture.log")

        let proc = try spawnHeadless(env: env, extraEnv: [
            "WDM_TEST_CAPTURE_LOG": captureLog.path
        ])
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        let resetRef = try await findRef(port: port, id: "inspector.action.reset")
        try await postClick(port: port, ref: resetRef)

        try await waitForFileLine(url: captureLog, contains: "release id=", timeoutMs: 3000)

        let log = (try? String(contentsOf: captureLog)) ?? ""
        #expect(log.contains("capture id=1"),
                "expected capture id=1 (default-selected); got log:\n\(log)")
        #expect(log.contains("release id=1"),
                "expected release id=1; got log:\n\(log)")
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
