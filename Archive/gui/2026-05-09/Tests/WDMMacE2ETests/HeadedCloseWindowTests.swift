import Testing
import Foundation
@testable import WDMRemoteControl

@Suite("Headed: close-window via /ui/closeWindow")
struct HeadedCloseWindowTests {
    @Test func closeWindowAPIRoundTrip() async throws {
        guard headedEnabled() else { return }
        let api = try await MainActor.run { try sharedHeadedAPI() }
        // Closing a non-existent window returns staleRef — proves the API
        // path is wired without disrupting the shared instance.
        let absent = try await api.closeWindow(named: "no-such-window")
        #expect(absent["ok"] as? Bool == false,
                "closing a non-existent window should be ok:false, got \(absent)")
        #expect(absent["error"] as? String == "stale-ref",
                "closing a non-existent window should report stale-ref, got \(absent)")
    }

    /// Exclusive — closes the actual `Workshop Display Manager` window.
    /// Gated behind WDM_HEADED_CLOSE_E2E=1 so it doesn't break parallel runs.
    @Test func closesMainWindowExclusive() async throws {
        guard headedEnabled(),
              ProcessInfo.processInfo.environment["WDM_HEADED_CLOSE_E2E"] == "1"
        else { return }
        let api = try await MainActor.run { try sharedHeadedAPI() }
        let result = try await api.closeWindow(named: "Workshop Display Manager")
        #expect(result["ok"] as? Bool == true,
                "closeWindow(named: \"Workshop Display Manager\") returned \(result)")
    }
}
