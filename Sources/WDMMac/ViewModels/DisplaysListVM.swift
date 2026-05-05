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
        /// Display ID this one mirrors, if any. Surfaced as the
        /// "Mirror of 0X" tag in the Inspector HEADER per design briefing.
        public let mirrorSource: UInt32?
        public var isSelected: Bool

        public var id: String { remoteID }
    }

    @Published public private(set) var tiles: [Tile] = []
    @Published public private(set) var profiles: [String] = []
    @Published public private(set) var selectedRemoteID: String?
    @Published public private(set) var lastError: String?
    /// Refusal message specific to the VIRTUAL section. Populated by
    /// `refuseVirtualCreate()` so the GUI can surface "this isn't
    /// wired up yet" honestly per CLAUDE.md "no fakes".
    @Published public private(set) var virtualUnavailableMessage: String?
    @Published public internal(set) var flipSelection: [String: Flip] = [:]

    private let controller: WDMController
    private let overlayFlipper: OverlayFlipper
    private var observer: Task<Void, Never>?
    private var profilePoller: Task<Void, Never>?
    private var flipTask: Task<Void, Never>?
    private var flipGeneration: UInt64 = 0

    public init(controller: WDMController, overlayFlipper: OverlayFlipper) {
        self.controller = controller
        self.overlayFlipper = overlayFlipper
    }

    deinit {
        observer?.cancel()
        profilePoller?.cancel()
        flipTask?.cancel()
        overlayFlipper.stop()
    }

    /// Subscribe to display plug/unplug/mode-change events and reload the
    /// tile list whenever one fires.
    public func startObservingReconfigurations() {
        observer?.cancel()
        observer = controller.observeReconfigurations { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    /// Poll the profile store every `intervalSeconds` seconds so external
    /// `wdm save` / `wdm profiles remove` invocations in another terminal
    /// flow into the GUI without requiring user interaction. The cost is
    /// negligible — one `contentsOfDirectory` call every poll.
    public func startPollingProfiles(intervalSeconds: Double = 2.0) {
        profilePoller?.cancel()
        let nanos = UInt64(intervalSeconds * 1_000_000_000)
        profilePoller = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: nanos)
                if Task.isCancelled { return }
                await MainActor.run { self?.reloadProfiles() }
            }
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

    /// Set the primary (main) display — same Kit op as `wdm main <id>`.
    /// Surfaces failures via `lastError` per CLAUDE.md "honest
    /// unsupported-path policy".
    public func makeMain(displayID: UInt32) {
        do {
            _ = try controller.main(String(displayID), confirmer: AutoYesConfirmer())
            lastError = nil
        } catch {
            lastError = "Make main failed: \(error)"
        }
        reload()
    }

    /// Honest refusal for Inspector actions whose GUI wiring is on the
    /// v1.1 backlog (PiP / Record / Reset). The CLI command is the
    /// supported path. Surfaces a message in `lastError` so the user
    /// sees WHY the click didn't do anything.
    public func refuseAction(named name: String, cliEquivalent: String) {
        lastError = "\(name) via the GUI is on the v1.1 backlog. CLI: `\(cliEquivalent)`"
    }

    /// Set physical rotation for a display via `controller.rotate(...)`
    /// (same Kit op as `wdm rotate <id> <0|90|180|270>`). On Apple
    /// Silicon built-ins where IODisplayConnect isn't exposed, this
    /// throws and the error message surfaces in `lastError` per
    /// CLAUDE.md "honest unsupported-path policy".
    public func setRotation(displayID: UInt32, degrees: Int) {
        do {
            _ = try controller.rotate(String(displayID), degrees: degrees, confirmer: AutoYesConfirmer())
            lastError = nil
        } catch {
            lastError = "Rotate to \(degrees)° failed: \(error)"
        }
        reload()
    }

    /// Apply a SOFTWARE overlay flip via the same in-process Kit op
    /// the CLI uses (`controller.flipOverlay` → `AppKitOverlayFlipper`).
    ///
    /// Runs on a DETACHED background thread, NOT on the main actor.
    /// AppKitOverlayFlipper.run() pumps its own RunLoop synchronously
    /// for `durationMs` and internally schedules
    /// `Task { @MainActor in startStream() }` which it then waits on
    /// via semaphore. If we called it from `Task { @MainActor in … }`,
    /// the inner Task could never run because main actor would be
    /// held by our outer Task — instant deadlock. The detached path
    /// runs on a background thread; the flipper's internal main-thread
    /// dispatches drive the AppKit window correctly, and the
    /// background thread's RunLoop pump satisfies the run() contract.
    public func applyFlip(displayID: UInt32, flip: Flip) {
        // Persist by tile remoteID — this is what `flip(forRemoteID:)`
        // reads, what the segment selection bindings observe, and what
        // the snapshot exposes. Writing only by `String(displayID)` made
        // the H/V segment lights look stale because they read by
        // remoteID and never saw the write.
        flipSelection["displays.tile.\(displayID)"] = flip
        flipGeneration &+= 1
        let generation = flipGeneration
        let previous = flipTask
        previous?.cancel()
        overlayFlipper.stop()
        guard flip != .none else {
            lastError = nil
            flipTask = nil
            return
        }
        let alias = String(displayID)
        let captureFlipper = overlayFlipper
        let captureController = controller
        flipTask = Task.detached(priority: .userInitiated) { [weak self] in
            await previous?.value
            guard !Task.isCancelled else { return }
            do {
                // Sticky flip: durationMs=nil means run until stop().
                // The CLI's `wdm flip-overlay 1 h` works the same way
                // (no --duration-ms = nil); the GUI must match. The
                // overlay is torn down on the NEXT user click via
                // `overlayFlipper.stop()` at the top of applyFlip.
                try captureController.flipOverlay(alias, flip: flip,
                                                  durationMs: nil,
                                                  using: captureFlipper)
                await MainActor.run { [weak self] in
                    self?.finishFlip(generation: generation, message: nil)
                }
            } catch {
                let msg = "Flip overlay failed: \(error). If this mentions 'Screen Recording', grant WDMMac.app permission in System Settings → Privacy & Security → Screen Recording, then quit & relaunch."
                await MainActor.run { [weak self] in
                    self?.finishFlip(generation: generation, message: msg)
                }
            }
        }
    }

    /// Combinable-toggle entry point for the flip row. Reads current
    /// flip state, calls into the WDMCore pure helper to compute the
    /// next flip, then applies it. Single orchestration point — used
    /// by both the SwiftUI Inspector and the remote-control registry.
    /// All math lives in WDMCore (Flip+Toggle.swift); this method is
    /// presentation-state glue, nothing else.
    public func toggleFlip(displayID: UInt32, clicked: Flip) {
        let current = flipSelection["displays.tile.\(displayID)"] ?? .none
        applyFlip(displayID: displayID, flip: current.toggling(clicked: clicked))
    }

    private func finishFlip(generation: UInt64, message: String?) {
        guard generation == flipGeneration else { return }
        lastError = message
        flipTask = nil
    }

    /// Honest refusal for the VIRTUAL section's `+` CTA. Virtual
    /// display creation goes through the CGVirtualDisplay SPI, which
    /// the GUI hasn't wired up yet — the CLI's `wdm virtual create`
    /// is the supported path. Setting the dedicated message field
    /// gives the user observable feedback (and AI agents an assertable
    /// signal) instead of a silent no-op.
    public func refuseVirtualCreate() {
        virtualUnavailableMessage =
            "Virtual display creation isn't wired through the GUI yet. Run `wdm virtual create --name <s> --mode WxH@Hz` from the CLI."
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
                    mirrorSource: d.mirrorSource,
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
