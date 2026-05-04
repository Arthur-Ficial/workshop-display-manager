import Testing
import Foundation
@testable import WDMRemoteControl

/// Exhaustive coverage e2e: spawns the bundled headed `WDMMac.app`, hits
/// `GET /ui/snapshot`, and asserts every expected `remoteID` literal
/// appears in the JSON. Covers all PASSIVE elements in one shot — drops
/// 23 violations from `make lint-remote-coverage` in a single test.
///
/// Opt-in via WDM_HEADED_E2E=1 — the test needs a real NSWindow + the
/// system AX framework.
@Suite("Headed snapshot covers every documented remoteID")
struct HeadedSnapshotCoverageTests {

    /// The full set of accessibilityIdentifier values the WDMMac frontend
    /// claims. Must stay in sync with Sources/WDMMac/. The lint enforces
    /// the inverse: every ID used in source must appear in some test.
    static let expected: [String] = [
        "titlebar.profile",
        "titlebar.tab.stage", "titlebar.tab.profiles", "titlebar.tab.recordings",
        "sidebar.virtual.add", "sidebar.virtual.empty", "sidebar.profiles.empty",
        "displays.tile.1", "stage.tile.1",
        "inspector.title", "inspector.mode.dropdown",
        "inspector.rotate.0", "inspector.rotate.90", "inspector.rotate.180", "inspector.rotate.270",
        "inspector.flip.none", "inspector.flip.h", "inspector.flip.v",
        "inspector.action.makeMain", "inspector.action.pip", "inspector.action.record",
        "inspector.action.reset", "inspector.action.advanced",
        "statusbar.daemon",
        "statusbar.count.real", "statusbar.count.virtual", "statusbar.count.pip",
        "statusbar.lastEvent",
        "statusbar.toggle.watch", "statusbar.toggle.advanced",
    ]

    @Test func everyRemoteIDInSnapshot() async throws {
        guard ProcessInfo.processInfo.environment["WDM_HEADED_E2E"] == "1" else { return }
        let inst = try await MainActor.run { try HeadedAppInstance.shared() }
        let port = inst.port
        let snap = try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        let tree = try SceneTreeJSON.decode(snap)
        let presentIDs = Set(tree.nodes.map(\.remoteID))

        var missing: [String] = []
        for id in Self.expected where !presentIDs.contains(id) {
            missing.append(id)
        }
        #expect(missing.isEmpty,
                "snapshot is missing \(missing.count) IDs: \(missing.sorted())")
    }
}
