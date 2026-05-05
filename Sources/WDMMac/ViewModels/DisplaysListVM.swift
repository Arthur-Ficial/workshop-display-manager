import Foundation
import SwiftUI
import WDMCore
import WDMKit

/// View-model for the displays list. Strictly thin: pulls data from
/// `WDMController.list()` (the lib), pushes elements into a registry-shaped
/// `RemoteEntry` array (decoupled from `WDMRemoteControl` so this lib stays
/// dependency-clean), and tracks the currently-selected `remoteID`.
///
/// Render-layer rule: no business logic here — just shaping data for the
/// view + dispatching selection back through a closure that the runner wires
/// to the registry.
@MainActor
public final class DisplaysListVM: ObservableObject {
    public struct Tile: Identifiable, Equatable, Sendable {
        public let remoteID: String
        public let displayID: UInt32
        public let title: String
        public let subtitle: String
        public let isMain: Bool
        public let rotationDegrees: Int
        /// Real display pixel dimensions — sent to the WebKit Stage so it
        /// can render every monitor at its true aspect ratio.
        public let widthPx: Int
        public let heightPx: Int
        /// Real display origin in display pixels — anchors the WebKit
        /// Stage's spatial layout. Updated only when the controller's
        /// arrangement changes (after a drag-end commits).
        public let originX: Int
        public let originY: Int
        /// Current brightness 0..1 — nil if the display has no DDC/CI or
        /// software-readable brightness (most external monitors). The
        /// Inspector's brightness section refuses to render a slider when
        /// nil, per CLAUDE.md's honest-unsupported-path policy.
        public let brightness: Float?
        public var isSelected: Bool

        public var id: String { remoteID }
    }

    @Published public private(set) var tiles: [Tile] = []
    @Published public private(set) var profiles: [String] = []
    @Published public private(set) var selectedRemoteID: String?
    @Published public private(set) var lastError: String?
    @Published public internal(set) var flipSelection: [String: Flip] = [:]

    private let controller: WDMController
    private var observer: Task<Void, Never>?

    public init(controller: WDMController) {
        self.controller = controller
    }

    deinit { observer?.cancel() }

    /// Subscribe to display plug/unplug/mode-change events and reload the
    /// tile list whenever one fires.
    public func startObservingReconfigurations() {
        observer?.cancel()
        observer = controller.observeReconfigurations { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    /// Live read of saved profile names — drives the sidebar PROFILES section.
    /// Sorted alphabetically by ProfileStore so the order is stable across runs.
    public func reloadProfiles() {
        do {
            profiles = try controller.profiles()
        } catch {
            lastError = "\(error)"
            profiles = []
        }
    }

    /// Workshop facilitator's flagship action: click a profile, snap the
    /// displays back to that arrangement. Routes through the same Kit op
    /// the CLI's `wdm restore` exposes, with the auto-yes confirmer (no
    /// terminal prompt is reachable in the GUI flow).
    public func restoreProfile(named name: String) {
        do {
            _ = try controller.restoreProfile(name, confirmer: AutoYesConfirmer())
            lastError = nil
        } catch {
            lastError = "\(error)"
        }
        reload()
    }

    /// Delete a profile by name. Routes through the same Kit op the
    /// CLI's `wdm profiles remove <name>` exposes. After delete,
    /// reloadProfiles() refreshes the sidebar so the row disappears.
    public func removeProfile(named name: String) {
        do {
            try controller.removeProfile(name)
            lastError = nil
        } catch {
            lastError = "\(error)"
        }
        reloadProfiles()
    }

    /// Save the current arrangement as a new profile. The GUI has no text
    /// entry yet, so the name is stamped from the wall clock —
    /// `snapshot-YYYYMMDD-HHMMSS`. Workshop facilitator can rename later
    /// via `wdm profiles` if desired.
    public func saveCurrentAsProfile() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let name = "snapshot-\(formatter.string(from: Date()))"
        do {
            try controller.saveProfile(name)
            lastError = nil
        } catch {
            lastError = "\(error)"
        }
        reloadProfiles()
    }

    public func reload() {
        do {
            let displays = try controller.list()
            tiles = displays.map { d in
                Tile(
                    remoteID: "displays.tile.\(d.id)",
                    displayID: d.id,
                    title: d.name ?? "Display \(d.id)",
                    subtitle: "\(d.currentMode.width)×\(d.currentMode.height) @ \(Int(d.currentMode.refreshHz))Hz",
                    isMain: d.isMain,
                    rotationDegrees: d.rotationDegrees,
                    widthPx: d.currentMode.width,
                    heightPx: d.currentMode.height,
                    originX: d.origin.x,
                    originY: d.origin.y,
                    brightness: tryBrightness(displayID: d.id),
                    isSelected: d.id == displayIDFor(remoteID: selectedRemoteID)
                )
            }
            lastError = nil
        } catch {
            lastError = "\(error)"
            tiles = []
        }
    }

    /// Best-effort brightness read; nil on any error or unsupported display.
    /// Honest-unsupported-path: never lies and never invents a value.
    private func tryBrightness(displayID: UInt32) -> Float? {
        do { return try controller.brightness(String(displayID)) } catch { return nil }
    }

    /// Set brightness for one display via the same Kit op the CLI's
    /// `wdm brightness <id> <value>` exposes. Refreshes the tile list
    /// so the new value flows to the Inspector + remote registry.
    public func setBrightness(displayID: UInt32, value: Float) {
        do {
            _ = try controller.brightness(String(displayID), value: value, confirmer: AutoYesConfirmer())
            lastError = nil
        } catch {
            lastError = "\(error)"
        }
        reload()
    }

    private func displayIDFor(remoteID: String?) -> UInt32? {
        guard let remoteID, let id = remoteID.split(separator: ".").last,
              let n = UInt32(id) else { return nil }
        return n
    }

    public func select(remoteID: String) {
        selectedRemoteID = remoteID
        tiles = tiles.map { t in
            var copy = t
            copy.isSelected = (t.remoteID == remoteID)
            return copy
        }
    }

    public func isSelected(_ tile: Tile) -> Bool {
        tile.remoteID == selectedRemoteID
    }

    public func setFlip(_ flip: Flip, forRemoteID remoteID: String) {
        flipSelection[remoteID] = flip
    }

    public func flip(forRemoteID remoteID: String) -> Flip {
        flipSelection[remoteID] ?? .none
    }

    public func selectedTile() -> Tile? {
        if let id = selectedRemoteID, let t = tiles.first(where: { $0.remoteID == id }) {
            return t
        }
        return tiles.first
    }

    /// Commit a drag-end from the embedded WebKit Stage. Builds a fresh
    /// arrangement plan with the dragged display at the new origin and
    /// pushes it through `controller.setArrangement(_:confirmer:)` —
    /// same op the CLI exposes via `wdm arrange set`.
    public func commitDrag(displayID: UInt32, originX: Int, originY: Int) {
        do {
            let entries = try controller.arrangement().map { e -> ArrangementEntry in
                let origin = (e.id == displayID)
                    ? Point(x: originX, y: originY)
                    : e.origin
                return ArrangementEntry(id: e.id, origin: origin,
                                        rotationDegrees: e.rotationDegrees)
            }
            _ = try controller.setArrangement(entries, confirmer: AutoYesConfirmer())
            lastError = nil
        } catch {
            lastError = "\(error)"
        }
        reload()
    }
}
