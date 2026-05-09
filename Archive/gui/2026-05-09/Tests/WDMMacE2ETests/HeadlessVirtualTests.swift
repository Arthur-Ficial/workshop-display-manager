import Testing
import Foundation
@testable import WDMRemoteControl

/// VIRTUAL section parity with PROFILES bottom-CTA pattern, plus
/// honest-refusal click behaviour. Per
/// `tasks/virtual-section-design-align-spec.md`.
@Suite("wdm-mac headless: VIRTUAL sidebar — bottom CTA + honest refusal")
struct HeadlessVirtualTests {
    /// `sidebar.virtual.add` must appear in the headless registry so AI
    /// agents can drive it without going through AppKit AX. Today it
    /// only exists on the SwiftUI side, invisible to the headless
    /// adapter — RED until WDMMacRemoteRunner registers it.
    @Test func virtualAddRegisteredHeadlessly() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        let snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let ids = Set(snap.nodes.map(\.remoteID))
        #expect(ids.contains("sidebar.virtual.add"),
                "sidebar.virtual.add must be in the headless registry; got \(ids.sorted())")
    }

    /// Drives the failure path: when the recording manager is asked to
    /// throw, the click sets `virtualUnavailableMessage`, which the
    /// registry exposes as `sidebar.virtual.lastError` for AI agents to
    /// observe. CLAUDE.md no-fakes pillar — clickable affordances that
    /// fail must surface the failure honestly, not silently no-op.
    @Test func virtualCreateFailureSurfacesLastError() async throws {
        let env = try makeEnv()
        // Force the recording manager to throw immediately by pointing
        // its log file at a path inside a non-existent parent dir —
        // the file write fails, manager.run rethrows.
        let badLog = env.dir.appendingPathComponent("nope/does/not/exist/virtual.log")

        let proc = try spawnHeadless(env: env, extraEnv: [
            "WDM_TEST_VIRTUAL_LOG": badLog.path
        ])
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        let addRef = try await findRef(port: port, id: "sidebar.virtual.add")
        try await postClick(port: port, ref: addRef)

        // Wait for the failure to propagate into the registry.
        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            let snap = try SceneTreeJSON.decode(
                try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
            )
            if snap.nodes.contains(where: { $0.remoteID == "sidebar.virtual.lastError" }) {
                return
            }
            try await Task.sleep(nanoseconds: 80_000_000)
        }
        Issue.record("sidebar.virtual.lastError never appeared after virtual-create failure")
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
