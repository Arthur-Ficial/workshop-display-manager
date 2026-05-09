import Foundation
import Combine
import AppKit
import WDMCore
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
        // Original wiring — preserves the combineLatest timing the existing
        // headless tests depend on.
        vm.$tiles.combineLatest(vm.$selectedRemoteID, vm.$profiles)
            .combineLatest(vm.$virtualUnavailableMessage, vm.$lastError)
            .sink { [weak self] triple, virtualMsg, lastError in
                let (tiles, selected, profiles) = triple
                self?.sync(tiles: tiles, selected: selected, profiles: profiles,
                           virtualUnavailableMessage: virtualMsg,
                           lastError: lastError,
                           safeTxVisible: self?.vm.safeTx.visible ?? false,
                           safeTxMessage: self?.vm.safeTx.message ?? "",
                           safeTxSecondsRemaining: self?.vm.safeTx.secondsRemaining ?? 0)
            }
            .store(in: &cancellables)
        // SafeTx banner state restamps separately. The banner only appears
        // mid-mutation (after the user clicks a destructive action and
        // before the keep/revert decision), so it's a low-frequency signal
        // and the duplicate-restamp cost is negligible.
        vm.safeTx.$visible.combineLatest(vm.safeTx.$message, vm.safeTx.$secondsRemaining)
            .dropFirst()  // skip initial-value emit; main pipeline already restamped
            .sink { [weak self] _ in
                guard let self else { return }
                self.sync(tiles: self.vm.tiles, selected: self.vm.selectedRemoteID,
                          profiles: self.vm.profiles,
                          virtualUnavailableMessage: self.vm.virtualUnavailableMessage,
                          lastError: self.vm.lastError,
                          safeTxVisible: self.vm.safeTx.visible,
                          safeTxMessage: self.vm.safeTx.message,
                          safeTxSecondsRemaining: self.vm.safeTx.secondsRemaining)
            }
            .store(in: &cancellables)
    }

    private func sync(tiles: [DisplaysListVM.Tile], selected: String?, profiles: [String],
                      virtualUnavailableMessage: String?,
                      lastError: String?,
                      safeTxVisible: Bool = false,
                      safeTxMessage: String = "",
                      safeTxSecondsRemaining: Int = 0) {
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
            let displaysClick = mainClick { [vm] in
                vm.select(remoteID: displaysID)
            }
            let entry = RemoteRegistry.Entry(
                role: "button", label: tile.title, value: tile.subtitle,
                state: NodeState(selected: displaysID == selected, enabled: true),
                onClick: displaysClick
            )
            entries.append((displaysID, entry))
            entries.append((stageID, entry))
        }
        // Wallpaper URL passive nodes — emitted AFTER the per-tile
        // click targets so the @e refs remain stable for click tests.
        // Namespace `displays.wallpaper.<id>` (not `displays.tile.<id>.*`)
        // keeps the existing `displays.tile.` prefix-filter in
        // SnapshotE2ETests intact.
        for tile in tiles {
            guard let wpURL = tile.wallpaperURL else { continue }
            entries.append(("displays.wallpaper.\(tile.displayID)", RemoteRegistry.Entry(
                role: "text", label: "Wallpaper", value: wpURL.path,
                state: NodeState(selected: false, enabled: true),
                onClick: nil
            )))
        }
        // VIRTUAL section — `+` CTA + honest-refusal message. The CTA
        // is always present (matches the design briefing's bottom-CTA
        // pattern); clicking it surfaces a concrete refusal message
        // instead of a silent no-op.
        let virtualClick = mainClick { [vm] in
            vm.createVirtualDisplay()
        }
        entries.append(("sidebar.virtual.add", RemoteRegistry.Entry(
            role: "button", label: "Add virtual display", value: nil,
            state: NodeState(selected: false, enabled: true),
            onClick: virtualClick
        )))
        for name in vm.activeVirtualNames() {
            let removeClick = mainClick { [vm] in
                vm.removeVirtualDisplay(named: name)
            }
            entries.append(("sidebar.virtual.row.\(name).remove", RemoteRegistry.Entry(
                role: "button", label: "Remove virtual \(name)", value: nil,
                state: NodeState(selected: false, enabled: true),
                onClick: removeClick
            )))
        }
        if let msg = virtualUnavailableMessage, !msg.isEmpty {
            entries.append(("sidebar.virtual.lastError", RemoteRegistry.Entry(
                role: "text", label: "Virtual display creation unavailable",
                value: msg,
                state: NodeState(selected: false, enabled: true),
                onClick: nil
            )))
        }

        // INSPECTOR HEADER — Mirror-of tag. When the selected tile mirrors
        // another, surface "Mirror of 0X" (1-based index of the source
        // in the visible tile list, matches Stage badge format).
        if let tile = (tiles.first { $0.remoteID == selected } ?? tiles.first),
           let src = tile.mirrorSource,
           let idx = tiles.firstIndex(where: { $0.displayID == src }) {
            let label = String(format: "Mirror of %02d", idx + 1)
            entries.append(("inspector.title.mirror", RemoteRegistry.Entry(
                role: "text", label: "Mirror tag", value: label,
                state: NodeState(selected: false, enabled: true),
                onClick: nil
            )))
        }

        // INSPECTOR — last-error surfacing for the GEOMETRY section.
        // When a rotate/flip click fails (e.g. Screen Recording
        // permission denied for the overlay flipper, or rotation
        // refused on Apple Silicon built-ins), the human needs to SEE
        // why — not stare at an unchanged screen. Honest-unsupported-
        // path per CLAUDE.md.
        if let err = lastError, !err.isEmpty {
            entries.append(("inspector.geometry.lastError", RemoteRegistry.Entry(
                role: "text", label: "Last action error", value: err,
                state: NodeState(selected: false, enabled: true),
                onClick: nil
            )))
        }

        // INSPECTOR — GEOMETRY rotation + flip segments. Same selected-
        // tile scoping as brightness. Each segment routes to the same
        // Kit op the CLI exposes (`wdm rotate`, `wdm flip`).
        if let tile = (tiles.first { $0.remoteID == selected } ?? tiles.first) {
            let displayID = tile.displayID
            for degrees in [0, 90, 180, 270] {
                let id = "inspector.rotate.\(degrees)"
                let click = mainClick { [vm] in
                    vm.setRotation(displayID: displayID, degrees: degrees)
                }
                entries.append((id, RemoteRegistry.Entry(
                    role: "button", label: "\(degrees)°", value: nil,
                    state: NodeState(selected: tile.rotationDegrees == degrees, enabled: true),
                    onClick: click
                )))
            }
            for (axis, flip, label) in [
                ("none", Flip.none, "—"),
                ("h", Flip.horizontal, "Flip H"),
                ("v", Flip.vertical, "Flip V"),
            ] {
                let id = "inspector.flip.\(axis)"
                // SSOT: both /ui/click and the SwiftUI Button funnel
                // through `vm.toggleFlip`, which uses the WDMCore
                // `Flip.toggling(clicked:)` math. `hasAxis` is the
                // matching pure predicate for the lit segments.
                let click = mainClick { [vm] in
                    vm.toggleFlip(displayID: displayID, clicked: flip)
                }
                let isSelected = vm.flip(forRemoteID: tile.remoteID).hasAxis(flip)
                entries.append((id, RemoteRegistry.Entry(
                    role: "button", label: label, value: nil,
                    state: NodeState(selected: isSelected, enabled: true),
                    onClick: click
                )))
            }
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
                // Human-friendly percentage matches macOS System Settings.
                let value = "\(Int((level * 100).rounded()))%"
                entries.append(("inspector.brightness.value", RemoteRegistry.Entry(
                    role: "text", label: "Brightness", value: value,
                    state: NodeState(selected: false, enabled: true),
                    onClick: nil
                )))
                let displayID = tile.displayID
                for preset in [25, 50, 75, 100] {
                    let presetID = "inspector.brightness.value.\(String(format: "%03d", preset))"
                    let presetValue = Float(preset) / 100.0
                    let click = mainClick { [vm] in
                        vm.setBrightness(displayID: displayID, value: presetValue)
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

            // INSPECTOR — actions section. "Make main" is wired to the
            // live Kit op; the others surface honest refusals (per
            // CLAUDE.md "no fakes — surface the limitation"). The
            // SwiftUI tree wires them too; the registry exposes them
            // here so the headless /ui/click path also works.
            let displayID = tile.displayID
            entries.append(("inspector.action.makeMain", RemoteRegistry.Entry(
                role: "button", label: "Make main", value: nil,
                state: NodeState(selected: false, enabled: true),
                onClick: mainClick { [vm] in vm.makeMain(displayID: displayID) }
            )))
            entries.append(("inspector.action.pip", RemoteRegistry.Entry(
                role: "button", label: "Open PiP window", value: nil,
                state: NodeState(selected: false, enabled: true),
                onClick: mainClick { [vm] in
                    vm.refuseAction(named: "PiP window",
                                    cliEquivalent: "wdm pip \(displayID)")
                }
            )))
            entries.append(("inspector.action.record", RemoteRegistry.Entry(
                role: "button", label: "Record", value: nil,
                state: NodeState(selected: false, enabled: true),
                onClick: mainClick { [vm] in
                    vm.refuseAction(named: "Record",
                                    cliEquivalent: "wdm record \(displayID) --out <path> --duration <sec>")
                }
            )))
            entries.append(("inspector.action.reset", RemoteRegistry.Entry(
                role: "button", label: "Reset / reconnect…", value: nil,
                state: NodeState(selected: false, enabled: true),
                onClick: mainClick { [vm] in
                    vm.refuseAction(named: "Reset",
                                    cliEquivalent: "wdm doctor disconnect \(displayID)")
                }
            )))
            entries.append(("inspector.action.advanced", RemoteRegistry.Entry(
                role: "button", label: "Open Advanced", value: nil,
                state: NodeState(selected: false, enabled: true),
                onClick: mainClick {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            )))
            // Change background — opens NSOpenPanel in headed mode; in
            // hermetic headless tests, WDM_TEST_WALLPAPER_PATH env var
            // substitutes for the panel so the click can drive the same
            // vm.changeBackground Kit op the SwiftUI button does. The
            // env-var path is gated to non-empty values; with the var
            // unset, the click surfaces an honest refusal pointing at
            // the CLI.
            let captureID = displayID
            entries.append(("inspector.action.change-background", RemoteRegistry.Entry(
                role: "button", label: "Change background", value: nil,
                state: NodeState(selected: false, enabled: true),
                onClick: mainClick { [vm] in
                    let env = ProcessInfo.processInfo.environment
                    if let path = env["WDM_TEST_WALLPAPER_PATH"], !path.isEmpty {
                        vm.changeBackground(displayID: captureID,
                                            to: URL(fileURLWithPath: path))
                    } else {
                        vm.refuseAction(named: "Change background",
                                        cliEquivalent: "wdm wallpaper set \(captureID) <path>")
                    }
                }
            )))
        }

        // PROFILES section header `+` button — saves the current arrangement
        // as `snapshot-<timestamp>` and refreshes the sidebar.
        let saveID = "sidebar.profiles.add"
        let saveClick = mainClick { [vm] in
            vm.saveCurrentAsProfile()
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
            let click = mainClick { [vm] in
                vm.restoreProfile(named: name)
            }
            entries.append((rowID, RemoteRegistry.Entry(
                role: "button", label: name, value: nil,
                state: NodeState(selected: rowID == selected, enabled: true),
                onClick: click
            )))
            // Per-row delete (`× ` button next to the row). Same Kit
            // op the CLI's `wdm profiles remove` exposes.
            let deleteID = "sidebar.profiles.row.\(name).delete"
            let deleteClick = mainClick { [vm] in
                vm.removeProfile(named: name)
            }
            entries.append((deleteID, RemoteRegistry.Entry(
                role: "button", label: "Delete \(name)", value: nil,
                state: NodeState(selected: false, enabled: true),
                onClick: deleteClick
            )))
        }
        // SAFETX banner — only present while a Kit op awaits keep/revert.
        // Adds 4 entries: passive (countdown + banner) and clickable
        // (keep + revert). All routed to vm.safeTx.{keep,revert}.
        if safeTxVisible {
            let safeTx = vm.safeTx
            let labelText = safeTxMessage.isEmpty ? "Display change applied" : safeTxMessage
            entries.append(("safetx.banner", RemoteRegistry.Entry(
                role: "panel", label: "Safe-tx confirmation banner",
                value: labelText,
                state: NodeState(selected: false, enabled: true),
                onClick: nil
            )))
            entries.append(("safetx.banner.countdown", RemoteRegistry.Entry(
                role: "text", label: "Reverting in",
                value: "\(safeTxSecondsRemaining)s",
                state: NodeState(selected: false, enabled: true),
                onClick: nil
            )))
            entries.append(("safetx.banner.keep", RemoteRegistry.Entry(
                role: "button", label: "Keep", value: nil,
                state: NodeState(selected: false, enabled: true),
                onClick: mainClick { safeTx.keep() }
            )))
            entries.append(("safetx.banner.revert", RemoteRegistry.Entry(
                role: "button", label: "Revert", value: nil,
                state: NodeState(selected: false, enabled: true),
                onClick: mainClick { safeTx.revert() }
            )))
        }
        registry.replace(entries: entries)
    }

    private func mainClick(_ body: @MainActor @Sendable @escaping () -> Void) -> @Sendable () -> Void {
        {
            if Thread.isMainThread {
                MainActor.assumeIsolated { body() }
            } else {
                DispatchQueue.main.sync {
                    MainActor.assumeIsolated { body() }
                }
            }
        }
    }
}
