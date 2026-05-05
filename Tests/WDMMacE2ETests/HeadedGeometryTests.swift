import Testing
import Foundation
@testable import WDMRemoteControl

/// Visual headed e2e for the GEOMETRY section. Per SPEC.md "Always
/// do" rule and CLAUDE.md "tests must actually run" — the headless
/// suite proves the registry contract; this proves the SwiftUI view
/// is laid out and the AX tree exposes the segments to a real human.
@Suite("Headed: GEOMETRY rotation + flip clicks dispatch through the AX tree")
struct HeadedGeometryTests {
    /// REGRESSION: a real Flip H click against the headed app must
    /// not kill the process. Stress-tests with FIVE clicks
    /// (single + four rapid back-to-back) — the rapid clicks force
    /// the flipper's defensive `teardown()` at re-entry to race
    /// the previous flip's still-flushing SCStream callbacks.
    /// User-reported crash 2026-05-05.
    @Test func flipDoesNotCrashHeadedApp() async throws {
        guard headedEnabled() else { return }
        let api = try await MainActor.run { try sharedHeadedAPI() }
        let env = try makeHeadedEnv()
        let stateBytes = try Data(contentsOf: env.stateFile)
        let stateJson = (try JSONSerialization.jsonObject(with: stateBytes) as? [String: Any]) ?? [:]
        let pid = pid_t(stateJson["pid"] as? Int ?? 0)
        let port = UInt16(stateJson["port"] as? Int ?? 0)
        try #require(pid != 0, "could not read live wdm-mac pid")

        // Round 1: single click, full settle.
        _ = try await api.clickRemoteID("inspector.flip.h")
        try await Task.sleep(nanoseconds: 1_200_000_000)
        #expect(kill(pid, 0) == 0,
                "wdm-mac died after first Flip H — crash regression")
        #expect(isPortAccepting(port: port),
                "wdm-mac listener died after first Flip H")

        // Round 2: rapid back-to-back to race teardown.
        for _ in 0..<4 {
            _ = try await api.clickRemoteID("inspector.flip.h")
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        try await Task.sleep(nanoseconds: 1_500_000_000)
        #expect(kill(pid, 0) == 0,
                "wdm-mac died during rapid Flip H clicks — teardown race")
        #expect(isPortAccepting(port: port),
                "wdm-mac listener died during rapid Flip H clicks")
    }

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
