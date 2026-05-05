import Testing
import Foundation
@testable import WDMRemoteControl

/// Asserts every CLICKABLE remoteID in WDMMac is dispatchable through
/// `POST /ui/click` and returns ok:true.
@Suite("Headed: every clickable remoteID is dispatchable via /ui/click")
struct HeadedClickCoverageTests {
    static let clickable: [String] = [
        "titlebar.tab.stage", "titlebar.tab.profiles", "titlebar.tab.recordings",
        "titlebar.profile",
        "sidebar.virtual.add",
        "displays.tile.1", "stage.tile.1",
        "inspector.mode.dropdown",
        "inspector.rotate.0", "inspector.rotate.90", "inspector.rotate.180", "inspector.rotate.270",
        "inspector.flip.none", "inspector.flip.h", "inspector.flip.v",
        "inspector.brightness.value.025", "inspector.brightness.value.050",
        "inspector.brightness.value.075", "inspector.brightness.value.100",
        "inspector.action.makeMain", "inspector.action.pip", "inspector.action.record",
        "inspector.action.reset", "inspector.action.advanced",
        "statusbar.toggle.watch", "statusbar.toggle.advanced",
    ]

    @Test func everyClickableDispatchable() async throws {
        guard headedEnabled() else { return }
        let api = try await MainActor.run { try sharedHeadedAPI() }
        var failed: [String] = []
        for id in Self.clickable {
            let result = try await api.clickRemoteID(id)
            if result["ok"] as? Bool != true {
                failed.append("\(id) -> \(result)")
            }
        }
        #expect(failed.isEmpty, "clicks failed for: \(failed)")
    }
}
