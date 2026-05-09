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

    // The former virtualAddClickProducesHonestRefusal test was deleted
    // because the GUI now actually creates the virtual display on click —
    // the live behaviour is covered by HeadlessVirtualCreateTests, which
    // asserts a `run` line in the recording manager log. The "honest
    // refusal" surface is preserved for the SPI-unavailable failure path
    // (CGVirtualDisplayManager throws → vm.virtualUnavailableMessage),
    // but that branch isn't reachable from a hermetic test on a
    // CGVirtualDisplay-capable macOS build.
}
