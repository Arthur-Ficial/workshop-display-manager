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
        vm.$tiles
            .sink { [weak self] tiles in self?.sync(tiles: tiles) }
            .store(in: &cancellables)
    }

    private func sync(tiles: [DisplaysListVM.Tile]) {
        let registry = self.registry
        let vm = self.vm
        registry.reset()
        for tile in tiles {
            let id = tile.remoteID
            registry.upsert(remoteID: id, entry: .init(
                role: "button",
                label: tile.title,
                value: tile.subtitle,
                state: NodeState(selected: tile.isSelected, enabled: true),
                onClick: { Task { @MainActor in vm.select(remoteID: id) } }
            ))
        }
    }
}
