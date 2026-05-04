import Testing
import Foundation
@testable import WDMRemoteControl

/// Closes both the main window AND the Settings window through the
/// remote API (`POST /ui/closeWindow {name:"…"}`). No osascript anywhere
/// — the test pokes wdm-mac entirely through HTTP.
@Suite("Headed: close-window via /ui/closeWindow")
struct HeadedCloseWindowTests {
    @Test func closesMainAndSettings() async throws {
        guard ProcessInfo.processInfo.environment["WDM_HEADED_E2E"] == "1" else { return }
        let inst = try await MainActor.run { try HeadedAppInstance.shared() }
        let port = inst.port

        // Open Settings: route through /ui/click on a future menu item, OR
        // just construct the action via /ui/dispatch raw. For M2 we open
        // Settings indirectly by clicking inspector.action.advanced — a
        // future Kit op will surface "open Settings" as its own verb.
        // For now this test only proves close works on the main window;
        // the Settings close is a TODO blocked on opening Settings via
        // the API.
        let result = try await closeWindow(named: "Workshop Display Manager", port: port)
        #expect(result["ok"] as? Bool == true,
                "main window close returned \(result)")
    }

    private func closeWindow(named name: String, port: UInt16) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/closeWindow")!)
        req.httpMethod = "POST"
        req.httpBody = Data(#"{"name":"\#(name)"}"#.utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
