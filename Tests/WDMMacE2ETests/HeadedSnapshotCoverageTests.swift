import Testing
import Foundation
@testable import WDMRemoteControl

/// Asserts every documented WDMMac `accessibilityIdentifier` literal
/// appears in `/ui/snapshot`. Covers all PASSIVE elements in one shot.
@Suite("Headed snapshot covers every documented remoteID")
struct HeadedSnapshotCoverageTests {
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
        guard headedEnabled() else { return }
        let api = try await MainActor.run { try sharedHeadedAPI() }
        let tree = try await api.snapshot()
        let present = Set(tree.nodes.map(\.remoteID))
        let missing = Self.expected.filter { !present.contains($0) }
        #expect(missing.isEmpty,
                "snapshot is missing \(missing.count) IDs: \(missing.sorted())")
    }
}
