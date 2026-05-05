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
        // Tiles, selection, OR profiles changing must restamp the registry —
        // selection flips the `selected` state flag, profiles add/remove rows.
        vm.$tiles.combineLatest(vm.$selectedRemoteID, vm.$profiles)
            .sink { [weak self] tiles, selected, profiles in
                self?.sync(tiles: tiles, selected: selected, profiles: profiles)
            }
            .store(in: &cancellables)
    }

    private func sync(tiles: [DisplaysListVM.Tile], selected: String?, profiles: [String]) {
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
        // INSPECTOR — brightness section, surfaced for the currently-
        // selected display only (mirrors the SwiftUI Inspector). For
        // supported displays: a passive `inspector.brightness.value`
        // text node carrying the current 0..1 value, plus four preset
        // click points (.025/.050/.075/.100) routed to setBrightness.
        // For unsupported displays: a single `inspector.brightness.unavailable`
        // text node — honest refusal per CLAUDE.md.
        let selectedTile = tiles.first { $0.remoteID == selected } ?? tiles.first
        if let tile = selectedTile {
            if let level = tile.brightness {
                let value = String(format: "%.2f", level)
                entries.append(("inspector.brightness.value", RemoteRegistry.Entry(
                    role: "text", label: "Brightness", value: value,
                    state: NodeState(selected: false, enabled: true),
                    onClick: nil
                )))
                let displayID = tile.displayID
                for preset in [25, 50, 75, 100] {
                    let presetID = "inspector.brightness.value.\(String(format: "%03d", preset))"
                    let presetValue = Float(preset) / 100.0
                    let click: @Sendable () -> Void = { [vm] in
                        Task { @MainActor in vm.setBrightness(displayID: displayID, value: presetValue) }
                    }
                    entries.append((presetID, RemoteRegistry.Entry(
                        role: "button", label: "\(preset)%", value: nil,
                        state: NodeState(selected: false, enabled: true),
                        onClick: click
                    )))
                }
            } else {
                entries.append(("inspector.brightness.unavailable", RemoteRegistry.Entry(
                    role: "text", label: "Brightness control unavailable on this display.",
                    value: nil,
                    state: NodeState(selected: false, enabled: true),
                    onClick: nil
                )))
            }
        }

        // PROFILES section header `+` button — saves the current arrangement
        // as `snapshot-<timestamp>` and refreshes the sidebar.
        let saveID = "sidebar.profiles.add"
        let saveClick: @Sendable () -> Void = { [vm] in
            Task { @MainActor in vm.saveCurrentAsProfile() }
        }
        entries.append((saveID, RemoteRegistry.Entry(
            role: "button", label: "Save current arrangement", value: nil,
            state: NodeState(selected: false, enabled: true),
            onClick: saveClick
        )))

        // PROFILES sidebar rows. Clicking one restores that profile via the
        // same Kit op the CLI's `wdm restore` exposes — workshop facilitator's
        // hot-swap-the-room gesture, one click. The fixture provider persists
        // the resulting arrangement; the e2e test asserts the on-disk shape
        // changed to prove the wiring is real.
        for name in profiles {
            let rowID = "sidebar.profiles.row.\(name)"
            let click: @Sendable () -> Void = { [vm] in
                Task { @MainActor in vm.restoreProfile(named: name) }
            }
            entries.append((rowID, RemoteRegistry.Entry(
                role: "button", label: name, value: nil,
                state: NodeState(selected: rowID == selected, enabled: true),
                onClick: click
            )))
            // Per-row delete (`× ` button next to the row). Same Kit
            // op the CLI's `wdm profiles remove` exposes.
            let deleteID = "sidebar.profiles.row.\(name).delete"
            let deleteClick: @Sendable () -> Void = { [vm] in
                Task { @MainActor in vm.removeProfile(named: name) }
            }
            entries.append((deleteID, RemoteRegistry.Entry(
                role: "button", label: "Delete \(name)", value: nil,
                state: NodeState(selected: false, enabled: true),
                onClick: deleteClick
            )))
        }
        registry.replace(entries: entries)
    }
}
