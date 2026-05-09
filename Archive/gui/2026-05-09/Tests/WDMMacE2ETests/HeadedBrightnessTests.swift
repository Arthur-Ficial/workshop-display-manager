import Testing
import Foundation
@testable import WDMRemoteControl

/// **Visual headed e2e** for the Inspector BRIGHTNESS section, gated
/// behind `WDM_HEADED_E2E=1` (run via `make e2e-fullflow` or similar).
/// Mirrors what the headless registry path proves, but against a real
/// SwiftUI window so the AccessibilityWalker has actual NSHostingView
/// children to walk — which is the only way to prove the slider /
/// refusal hint really exist for a human user, not just in our own
/// remote registry.
///
/// Per SPEC.md "Always do" → every feature ships a visual headed e2e.
/// The headless suite (`HeadlessBrightnessTests`) covers the contract
/// with the remote registry; this suite covers the contract with
/// AppKit's accessibility tree.
@Suite("Headed: Inspector BRIGHTNESS section reachable via /ui/snapshot")
struct HeadedBrightnessTests {
    /// On any built-in display (including the developer's MacBook
    /// Air's main display), `controller.brightness(...)` returns a
    /// real value, so `inspector.brightness.value` (the registry-
    /// driven readout) must surface in the AX tree. On unsupported
    /// displays, the refusal hint `inspector.brightness.unavailable`
    /// surfaces instead. Either way, exactly one of the two must be
    /// present — never neither, never both. That invariant only
    /// holds because the SwiftUI view actually rendered.
    ///
    /// Note: we don't assert on `inspector.brightness.slider` —
    /// SwiftUI's `Slider` does not reliably propagate its
    /// `accessibilityIdentifier` to the AppKit AX tree. The presence
    /// of the value node + four preset clicks is the load-bearing
    /// signal that the supported branch rendered.
    @Test func brightnessSectionAppearsInAXTree() async throws {
        guard headedEnabled() else { return }
        let api = try await MainActor.run { try sharedHeadedAPI() }

        _ = try await api.clickRemoteID("displays.tile.1")
        try await Task.sleep(nanoseconds: 300_000_000)

        let tree = try await api.snapshot()
        let ids = Set(tree.nodes.map(\.remoteID))
        let hasValue = ids.contains("inspector.brightness.value")
        let hasRefusal = ids.contains("inspector.brightness.unavailable")
        #expect(hasValue != hasRefusal,
                "exactly one of value-readout/refusal must surface; got value=\(hasValue) refusal=\(hasRefusal); ids=\(ids.sorted())")
    }

    /// Drives the four registry preset clicks against the headed app.
    /// On a built-in display these presets actually move the screen
    /// brightness — the workshop facilitator sees their MacBook
    /// brighten and dim under each click, by design. Each click goes
    /// through the same `/ui/click` route that `wdm-mac-control`
    /// uses, no osascript anywhere.
    @Test func presetClicksDispatchAgainstHeadedApp() async throws {
        guard headedEnabled() else { return }
        let api = try await MainActor.run { try sharedHeadedAPI() }
        _ = try await api.clickRemoteID("displays.tile.1")
        try await Task.sleep(nanoseconds: 300_000_000)

        // Only run the click sequence if brightness is supported on
        // this hardware. Headless tests already cover the unsupported
        // path; here we focus on the headed slider being driveable.
        let tree = try await api.snapshot()
        let ids = Set(tree.nodes.map(\.remoteID))
        guard ids.contains("inspector.brightness.value") else { return }

        for preset in ["025", "050", "075", "100"] {
            let id = "inspector.brightness.value.\(preset)"
            let r = try await api.clickRemoteID(id)
            #expect(r["ok"] as? Bool == true, "click \(id) -> \(r)")
            // Each click queues a Task → vm.setBrightness → controller
            // → DisplayServices write → reload → probe. The whole chain
            // is asynchronous; 600 ms gives DisplayServices time to
            // settle on real hardware before the next preset overwrites.
            try await Task.sleep(nanoseconds: 600_000_000)
        }
        // Final settle before the assertion-time snapshot — DisplayServices
        // brightness reads can lag the last write by a beat.
        try await Task.sleep(nanoseconds: 500_000_000)

        // After the last click (.100), the value node should reflect a
        // high brightness — but the controller probes the actual
        // hardware reading, which may drift a few percent from the 1.0
        // we wrote (DisplayServices clamps + rounds). Asserting "≥80%"
        // tolerates real-hardware drift while still catching a no-op
        // path (which would leave the value unchanged at the original
        // brightness, which on this user's MacBook tends to land much
        // lower).
        let after = try await api.snapshot()
        let value = after.nodes.first { $0.remoteID == "inspector.brightness.value" }
        let pct = value?.value
            .map { $0.replacingOccurrences(of: "%", with: "") }
            .flatMap { Int($0) } ?? -1
        #expect(pct >= 80,
                "after .100 click, value should be ≥ 80% (probe is hardware-real); got \(String(describing: value?.value))")
    }
}
