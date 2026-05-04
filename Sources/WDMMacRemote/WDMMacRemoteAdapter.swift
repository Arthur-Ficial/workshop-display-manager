import Foundation
import AppKit
import WDMRemoteControl

/// Adapts the WDMMac frontend to the `RemoteControllable` protocol. Two
/// snapshot strategies, used in order:
///
///   1. AccessibilityWalker — when a headed window is attached, walk
///      its NSAccessibility tree to expose EVERY element with an
///      `.accessibilityIdentifier`. This is how the GUI becomes 100%
///      remote-controllable without per-view registration plumbing.
///   2. RemoteRegistry — fallback for headless mode where no NSWindow
///      exists. The VM populates the registry with display tiles via
///      WDMMacRemoteRunner.
///
/// `attach(window:)` is called by HeadedRunner once the NSWindow is up.
public final class WDMMacRemoteAdapter: RemoteControllable, @unchecked Sendable {
    public let registry: RemoteRegistry
    private let walker = AccessibilityWalker()
    private weak var attachedWindow: NSWindow?

    public init(registry: RemoteRegistry) {
        self.registry = registry
    }

    @MainActor
    public func attach(window: NSWindow) {
        self.attachedWindow = window
    }

    public func snapshot(interactive: Bool) throws -> SceneTree {
        if attachedWindow != nil {
            return runOnMain { [walker, attachedWindow] in
                walker.snapshot(rootWindow: attachedWindow, interactive: interactive)
            }
        }
        return registry.currentTree()
    }

    public func dispatch(_ action: RemoteAction) throws -> ActionResult {
        // closeWindow goes through NSApp directly — works for any window the
        // app owns (main + Settings + future modals), no AX walk needed.
        if case .closeWindow(let name) = action {
            return runOnMain { Self.closeWindow(named: name) }
        }
        if attachedWindow != nil {
            return runOnMain { [walker] in walker.dispatch(action) }
        }
        let version = registry.snapshotVersion()
        switch action {
        case .click(let ref):
            guard let hit = registry.entry(forRef: ref), let onClick = hit.entry.onClick else {
                return .staleRef(snapshotVersion: version)
            }
            onClick()
            return .ok(snapshotVersion: registry.snapshotVersion())
        default:
            return .unsupported(snapshotVersion: version, reason: "M2 dispatches click only")
        }
    }

    /// Bridge from the server's background queue onto the main actor. The
    /// AccessibilityWalker is `@MainActor` so all calls into it must hop.
    /// Synchronous so the route handler stays linear.
    private func runOnMain<T: Sendable>(_ body: @MainActor @escaping () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { body() }
        }
        return DispatchQueue.main.sync { MainActor.assumeIsolated { body() } }
    }

    @MainActor
    static func closeWindow(named name: String) -> ActionResult {
        guard let window = NSApp.windows.first(where: { $0.title == name && $0.isVisible }) else {
            return .staleRef(snapshotVersion: 0)
        }
        window.performClose(nil)
        return .ok(snapshotVersion: 0)
    }
}
