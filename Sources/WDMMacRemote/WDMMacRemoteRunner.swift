import Foundation
import Combine
import WDMMac
import WDMRemoteControl

/// Owns the wiring between the SwiftUI VM and the registry that the
/// remote API reads. One source of truth: `vm.tiles`. Whenever it changes
/// (initial load, click, programmatic update) the registry is rebuilt to
/// match. Click handlers in the registry call back into `vm.select(_:)`,
/// which fires the next sync cycle. No state lives in two places.
@MainActor
public final class WDMMacRemoteRunner {
    public let registry: RemoteRegistry
    public let vm: DisplaysListVM
    private var cancellables: Set<AnyCancellable> = []

    public init(registry: RemoteRegistry, vm: DisplaysListVM) {
        self.registry = registry
        self.vm = vm
        // Either the tile list OR the selection changing must restamp the
        // registry — selection is what flips the `selected` state flag the
        // remote API exposes per node.
        vm.$tiles.combineLatest(vm.$selectedRemoteID)
            .sink { [weak self] tiles, selected in
                self?.sync(tiles: tiles, selected: selected)
            }
            .store(in: &cancellables)
    }

    private func sync(tiles: [DisplaysListVM.Tile], selected: String?) {
        let vm = self.vm
        var entries: [(String, RemoteRegistry.Entry)] = []
        for tile in tiles {
            let displaysID = tile.remoteID                  // displays.tile.X
            let stageID = "stage.tile.\(tile.displayID)"    // mirror inside Stage
            // Both registry rows trigger the same selection action so the
            // AI agent can click either the sidebar row or the Stage tile.
            // The Stage canvas is a WKWebView whose DOM children aren't
            // visible to the macOS AccessibilityWalker (it skips that
            // subtree to avoid a WebContent IPC deadlock), so the
            // registry has to carry the stage.tile.* mirror directly.
            let displaysClick: @Sendable () -> Void = { [vm] in
                Task { @MainActor in vm.select(remoteID: displaysID) }
            }
            let entry = RemoteRegistry.Entry(
                role: "button", label: tile.title, value: tile.subtitle,
                state: NodeState(selected: displaysID == selected, enabled: true),
                onClick: displaysClick
            )
            entries.append((displaysID, entry))
            entries.append((stageID, entry))
        }
        registry.replace(entries: entries)
    }
}
