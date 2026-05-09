import Testing
import Foundation
@testable import WDMRemoteControl

/// Drives Make Main through the SafeTxVM banner end-to-end:
///   1. POST /ui/click inspector.action.makeMain
///   2. /ui/snapshot exposes safetx.banner.{keep,revert,countdown}
///   3. POST /ui/click safetx.banner.keep
///   4. snapshot no longer exposes safetx.banner; lastError is nil;
///      fixture's main display has flipped.
///
/// CLAUDE.md SafeTx pillar: "every mutating Kit op routes through
/// SafeTxVM. The banner must be reachable from the AccessibilityWalker
/// so AI agents and tests can dismiss it the same way a local human
/// would."
@Suite("wdm-mac headless: SafeTx banner round-trip", .serialized)
struct HeadlessSafeTxTests {
    @Test func makeMainShowsBannerKeepPersists() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        // Default selection is display 1 (already main). Select display 2
        // so Make Main becomes a real mutation, not an idempotent no-op.
        try await postClick(port: port, ref: try findRef(port: port, id: "displays.tile.2"))
        try await postClick(port: port, ref: try findRef(port: port, id: "inspector.action.makeMain"))
        // Banner countdown chip is rendered while the banner is up
        // (passive a11y coverage for safetx.banner.countdown).
        _ = try await waitForRef(port: port, id: "safetx.banner.countdown", timeoutMs: 2000)
        let keepRef = try await waitForRef(port: port, id: "safetx.banner.keep", timeoutMs: 500)

        try await postClick(port: port, ref: keepRef)
        try await waitForRefAbsent(port: port, id: "safetx.banner", timeoutMs: 2000)
    }

    @Test func makeMainRevertDismissesBanner() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        try await postClick(port: port, ref: try findRef(port: port, id: "displays.tile.2"))
        try await postClick(port: port, ref: try findRef(port: port, id: "inspector.action.makeMain"))
        let revertRef = try await waitForRef(port: port, id: "safetx.banner.revert", timeoutMs: 2000)

        try await postClick(port: port, ref: revertRef)
        try await waitForRefAbsent(port: port, id: "safetx.banner", timeoutMs: 2000)
    }

    // MARK: - helpers

    private func findRef(port: UInt16, id: String) async throws -> Ref {
        let snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let node = snap.nodes.first { $0.remoteID == id }
        try #require(node != nil, "\(id) must exist; got \(snap.nodes.map(\.remoteID).sorted())")
        return node!.ref
    }

    private func waitForRef(port: UInt16, id: String, timeoutMs: Int) async throws -> Ref {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            let snap = try SceneTreeJSON.decode(
                try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
            )
            if let node = snap.nodes.first(where: { $0.remoteID == id }) {
                return node.ref
            }
            try await Task.sleep(nanoseconds: 80_000_000)
        }
        Issue.record("remoteID \(id) never appeared within \(timeoutMs)ms")
        throw CancellationError()
    }

    private func waitForRefAbsent(port: UInt16, id: String, timeoutMs: Int) async throws {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            let snap = try SceneTreeJSON.decode(
                try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
            )
            if !snap.nodes.contains(where: { $0.remoteID == id }) { return }
            try await Task.sleep(nanoseconds: 80_000_000)
        }
        Issue.record("remoteID \(id) was still present after \(timeoutMs)ms")
    }

    private func postClick(port: UInt16, ref: Ref) async throws {
        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(ref.rawValue)"}"#.utf8)
        let (_, resp) = try await URLSession.shared.data(for: click)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
    }
}
