import Testing
import Foundation
@testable import WDMRemoteControl

/// Asserts every CLICKABLE remoteID in WDMMac is dispatchable through
/// `POST /ui/click`. One test per click is overkill; one test that walks
/// every clickable node is sufficient and keeps the lint green.
@Suite("Headed: every clickable remoteID is dispatchable via /ui/click")
struct HeadedClickCoverageTests {

    /// Clickable IDs that must accept a /ui/click. (Tabs, sidebar +,
    /// stage tile, inspector mode/geometry/actions, statusbar toggles.)
    static let clickable: [String] = [
        "titlebar.tab.stage", "titlebar.tab.profiles", "titlebar.tab.recordings",
        "titlebar.profile",
        "sidebar.virtual.add",
        "displays.tile.1", "stage.tile.1",
        "inspector.mode.dropdown",
        "inspector.rotate.0", "inspector.rotate.90", "inspector.rotate.180", "inspector.rotate.270",
        "inspector.flip.none", "inspector.flip.h", "inspector.flip.v",
        "inspector.action.makeMain", "inspector.action.pip", "inspector.action.record",
        "inspector.action.reset", "inspector.action.advanced",
        "statusbar.toggle.watch", "statusbar.toggle.advanced",
    ]

    @Test func everyClickableDispatchable() async throws {
        guard ProcessInfo.processInfo.environment["WDM_HEADED_E2E"] == "1" else { return }
        let inst = try await MainActor.run { try HeadedAppInstance.shared() }
        let port = inst.port
        let snap = try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        let tree = try SceneTreeJSON.decode(snap)
        // Index by remoteID (first match wins — there can be duplicates
        // when AX inheritance applies; only buttons can be pressed).
        let buttonByID = Dictionary(grouping: tree.nodes.filter { $0.role == "button" },
                                    by: \.remoteID)
            .mapValues { $0.first! }

        var missing: [String] = []
        var failed: [String] = []
        for id in Self.clickable {
            guard let node = buttonByID[id] else {
                missing.append(id); continue
            }
            var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
            req.httpMethod = "POST"
            req.httpBody = Data(#"{"ref":"\#(node.ref.rawValue)"}"#.utf8)
            let (data, _) = try await URLSession.shared.data(for: req)
            let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if result?["ok"] as? Bool != true {
                failed.append("\(id) -> \(result ?? [:])")
            }
        }
        #expect(missing.isEmpty, "no clickable button found in snapshot for: \(missing)")
        #expect(failed.isEmpty, "click failed for: \(failed)")
    }
}
