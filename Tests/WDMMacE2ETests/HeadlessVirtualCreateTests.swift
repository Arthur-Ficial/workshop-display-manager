import Testing
import Foundation
@testable import WDMRemoteControl

/// Drives Virtual display creation through the GUI registry. With
/// WDM_TEST_VIRTUAL_LOG set, the headless app uses
/// RecordingVirtualDisplayManager — clicking sidebar.virtual.add writes
/// a `run name=… 1920x1080@60 hiDPI=true durationMs=nil` line to the
/// log. This proves the click path reaches WDMController.virtual.create
/// against the same primitive the CLI uses.
@Suite("wdm-mac headless: Virtual create flow", .serialized)
struct HeadlessVirtualCreateTests {
    @Test func clickingAddVirtualWritesRunLine() async throws {
        let env = try makeEnv()
        let virtualLog = env.dir.appendingPathComponent("virtual.log")

        let proc = try spawnHeadless(env: env, extraEnv: [
            "WDM_TEST_VIRTUAL_LOG": virtualLog.path
        ])
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        // Click +Add virtual display.
        let addRef = try await findRef(port: port, id: "sidebar.virtual.add")
        try await postClick(port: port, ref: addRef)

        // Wait for the recording manager to flush its run line.
        try await waitForFileLine(url: virtualLog, contains: "run name=", timeoutMs: 2000)

        let log = (try? String(contentsOf: virtualLog)) ?? ""
        #expect(log.contains("1920x1080@60"),
                "expected default 1920x1080 spec; got log:\n\(log)")
        #expect(log.contains("hiDPI=true"),
                "expected hiDPI default; got log:\n\(log)")
        #expect(log.contains("durationMs=nil"),
                "expected indefinite duration; got log:\n\(log)")
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
