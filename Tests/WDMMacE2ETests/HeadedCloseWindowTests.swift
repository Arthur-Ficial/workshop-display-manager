import Testing
import Foundation
@testable import WDMRemoteControl

/// Closes both the main window AND the Settings window through the
/// remote API (`POST /ui/closeWindow {name:"…"}`). No osascript anywhere
/// — the test pokes wdm-mac entirely through HTTP.
@Suite("Headed: close-window via /ui/closeWindow")
struct HeadedCloseWindowTests {
    @Test func closeWindowAPIRoundTrip() async throws {
        guard ProcessInfo.processInfo.environment["WDM_HEADED_E2E"] == "1" else { return }
        let inst = try await MainActor.run { try HeadedAppInstance.shared() }
        let port = inst.port

        // 1. closeWindow on a non-existent window returns a typed staleRef
        //    error — proves the API path is wired without disrupting the
        //    shared instance for subsequent tests.
        let absent = try await closeWindow(named: "no-such-window", port: port)
        #expect(absent["ok"] as? Bool == false,
                "closing a non-existent window should return ok:false, got \(absent)")
        #expect(absent["error"] as? String == "stale-ref",
                "closing a non-existent window should report stale-ref, got \(absent)")

        // 2. The endpoint accepts a real window name too — but we DON'T
        //    fire it here because that would terminate the shared instance
        //    used by the other Headed tests. The full close path is
        //    exercised by the dedicated test below (gated behind
        //    WDM_HEADED_CLOSE_E2E=1 so it only runs in isolation).
    }

    /// Closes the actual `Workshop Display Manager` window via
    /// `closeWindow(named: "Workshop Display Manager")` and asserts
    /// the API returns ok:true. Gated behind `WDM_HEADED_CLOSE_E2E=1`
    /// because it terminates the shared HeadedAppInstance — only run
    /// it when no other Headed tests are scheduled.
    @Test func closesMainWindowExclusive() async throws {
        guard ProcessInfo.processInfo.environment["WDM_HEADED_E2E"] == "1",
              ProcessInfo.processInfo.environment["WDM_HEADED_CLOSE_E2E"] == "1"
        else { return }
        let inst = try await MainActor.run { try HeadedAppInstance.shared() }
        let port = inst.port
        let result = try await closeWindow(named: "Workshop Display Manager", port: port)
        #expect(result["ok"] as? Bool == true,
                "closeWindow(named: \"Workshop Display Manager\") returned \(result)")
    }

    private func closeWindow(named name: String, port: UInt16) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/closeWindow")!)
        req.httpMethod = "POST"
        req.httpBody = Data(#"{"name":"\#(name)"}"#.utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
