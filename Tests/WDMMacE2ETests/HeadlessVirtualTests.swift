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

    /// Clicking the VIRTUAL `+` CTA must produce an observable
    /// honest-refusal — the registry exposes a
    /// `sidebar.virtual.lastError` text node carrying a clear
    /// "not yet wired" message after the click. CLAUDE.md "no fakes"
    /// rule: a button that does nothing on click is a fake.
    @Test func virtualAddClickProducesHonestRefusal() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        var snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let addBtn = snap.nodes.first { $0.remoteID == "sidebar.virtual.add" }
        try #require(addBtn != nil, "sidebar.virtual.add must exist; got \(snap.nodes.map(\.remoteID).sorted())")

        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(addBtn!.ref.rawValue)"}"#.utf8)
        let (_, resp) = try await URLSession.shared.data(for: click)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
        try await Task.sleep(nanoseconds: 300_000_000)

        snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let errorNode = snap.nodes.first { $0.remoteID == "sidebar.virtual.lastError" }
        try #require(errorNode != nil,
                     "sidebar.virtual.lastError must surface after click; ids=\(snap.nodes.map(\.remoteID).sorted())")
        let value = (errorNode?.value ?? errorNode?.label ?? "").lowercased()
        #expect(value.contains("virtual"),
                "refusal message should mention 'virtual'; got \(String(describing: errorNode?.value)) / \(String(describing: errorNode?.label))")
    }
}
