import Testing
import Foundation
@testable import WDMRemoteControl

/// Visual headed e2e for the GEOMETRY section. Per SPEC.md "Always
/// do" rule and CLAUDE.md "tests must actually run" — the headless
/// suite proves the registry contract; this proves the SwiftUI view
/// is laid out and the AX tree exposes the segments to a real human.
@Suite("Headed: GEOMETRY rotation + flip clicks dispatch through the AX tree")
struct HeadedGeometryTests {
    @Test func rotationAndFlipSegmentsAreDispatchable() async throws {
        guard headedEnabled() else { return }
        let api = try await MainActor.run { try sharedHeadedAPI() }

        // Select display 1 first so segments target it.
        _ = try await api.clickRemoteID("displays.tile.1")
        try await Task.sleep(nanoseconds: 250_000_000)

        // Each rotation segment should accept a click. On Apple Silicon
        // built-ins where IODisplayConnect isn't exposed, the click
        // returns ok:true (the action ran) but vm.lastError gets the
        // refusal — which is the correct honest path. The contract
        // here is "click is dispatchable", not "rotation succeeds".
        for degrees in [0, 90, 180, 270] {
            let r = try await api.clickRemoteID("inspector.rotate.\(degrees)")
            #expect(r["ok"] as? Bool == true, "click inspector.rotate.\(degrees) -> \(r)")
            try await Task.sleep(nanoseconds: 80_000_000)
        }
        for axis in ["none", "h", "v"] {
            let r = try await api.clickRemoteID("inspector.flip.\(axis)")
            #expect(r["ok"] as? Bool == true, "click inspector.flip.\(axis) -> \(r)")
            try await Task.sleep(nanoseconds: 80_000_000)
        }
    }
}
