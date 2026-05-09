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
        // Window-management verbs go through NSApp directly — they target
        // any window the app owns, no AX walk needed.
        switch action {
        case .closeWindow(let name):
            return runOnMain { Self.closeWindow(named: name) }
        case .raiseWindow(let name):
            return runOnMain { Self.raiseWindow(named: name) }
        case .keystroke(let key, let mods):
            return runOnMain { Self.keystroke(key: key, modifiers: mods) }
        case .screenshot(let window):
            return runOnMain { Self.screenshot(windowName: window) }
        case .waitForRemoteID(let remoteID, let timeoutMs):
            return runOnMain { [walker, attachedWindow] in
                Self.waitForRemoteID(remoteID, timeoutMs: timeoutMs,
                                     walker: walker, window: attachedWindow)
            }
        case .invokeMenu(let selector):
            return runOnMain { Self.invokeMenu(selector: selector) }
        default:
            break
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

    @MainActor
    static func raiseWindow(named name: String) -> ActionResult {
        guard let window = NSApp.windows.first(where: { $0.title == name }) else {
            return .staleRef(snapshotVersion: 0)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return .ok(snapshotVersion: 0)
    }

    /// Posts a synthetic keystroke as if the user typed it. The key string
    /// is mapped via `KeyMap`; modifiers are "command" / "shift" / "option" /
    /// "control" (lower-case). Replaces the AppleScript bridge for Cmd+, etc.
    @MainActor
    static func keystroke(key: String, modifiers: [String]) -> ActionResult {
        guard let code = KeyMap.virtualKeyCode(for: key) else {
            return .unsupported(snapshotVersion: 0, reason: "unknown key: \(key)")
        }
        var flags: CGEventFlags = []
        for m in modifiers {
            switch m.lowercased() {
            case "command", "cmd": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "option", "alt": flags.insert(.maskAlternate)
            case "control", "ctrl": flags.insert(.maskControl)
            default: break
            }
        }
        // Bring wdm-mac to front first — CGEvent posts go to whichever app
        // is frontmost; without raising, the keystroke would land on the
        // test runner / terminal that called the API.
        NSApp.activate(ignoringOtherApps: true)
        Thread.sleep(forTimeInterval: 0.15)
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)
        down?.flags = flags
        let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        return .ok(snapshotVersion: 0)
    }

    /// Captures a window (or the main window if `windowName` is nil) via
    /// `CGWindowListCreateImage`, encodes PNG, returns base64 in the
    /// result's `reason` slot. The route handler unpacks and serves bytes.
    @MainActor
    static func screenshot(windowName: String?) -> ActionResult {
        let window: NSWindow? = windowName == nil
            ? NSApp.windows.first(where: { $0.isVisible && !$0.title.isEmpty })
            : NSApp.windows.first(where: { $0.title == windowName! && $0.isVisible })
        guard let window, let view = window.contentView else {
            return .staleRef(snapshotVersion: 0)
        }
        // In-process screenshot via CALayer.render(in:) — captures the
        // SwiftUI layer tree directly, no /usr/sbin/screencapture
        // subprocess (which would trigger macOS TCC and prompt the user
        // for Screen Recording permission every launch).
        //
        // Trade-off: SwiftUI subtrees that haven't been rasterized into
        // their backing layer yet may be missing from the output. The
        // primary state surface is /ui/snapshot (the AX scene tree) —
        // screenshots are a secondary convenience for AI agents that
        // want to see, not just read.
        let bounds = view.bounds
        let scale = window.backingScaleFactor
        let pxW = Int(bounds.width * scale)
        let pxH = Int(bounds.height * scale)
        guard pxW > 0, pxH > 0,
              let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: pxW, height: pxH,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return .unsupported(snapshotVersion: 0, reason: "CGContext alloc failed")
        }
        ctx.scaleBy(x: scale, y: scale)
        if let layer = view.layer {
            layer.render(in: ctx)
        }
        // CGContext is bottom-left origin → flip the resulting image
        // so it reads top-left like every other PNG.
        guard let cgImage = ctx.makeImage() else {
            return .unsupported(snapshotVersion: 0, reason: "context makeImage failed")
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            return .unsupported(snapshotVersion: 0, reason: "PNG encoding failed")
        }
        return .okWithData(snapshotVersion: 0, payload: pngData.base64EncodedString())
    }

    /// Invokes a menu action by selector name. Goes through NSApp's
    /// responder chain, so it reaches the right target regardless of which
    /// app is currently frontmost. Use this instead of /ui/keystroke for
    /// menu items whose selectors we know.
    @MainActor
    static func invokeMenu(selector: String) -> ActionResult {
        let sel = NSSelectorFromString(selector)
        if NSApp.sendAction(sel, to: nil, from: nil) {
            return .ok(snapshotVersion: 0)
        }
        return .unsupported(snapshotVersion: 0,
                            reason: "no responder for selector: \(selector)")
    }

    /// Polls the snapshot until a node with the given `remoteID` appears
    /// (or the timeout elapses). Returns ok:true if found, staleRef otherwise.
    @MainActor
    static func waitForRemoteID(_ remoteID: String, timeoutMs: Int,
                                walker: AccessibilityWalker, window: NSWindow?) -> ActionResult {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutMs) / 1000.0)
        while Date() < deadline {
            let tree = walker.snapshot(rootWindow: window, interactive: false)
            if tree.nodes.contains(where: { $0.remoteID == remoteID }) {
                return .ok(snapshotVersion: tree.version)
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return .staleRef(snapshotVersion: 0)
    }
}

/// Map keystroke string → CGKeyCode. Only the keys we actually use; extend
/// as new tests need them.
enum KeyMap {
    static func virtualKeyCode(for key: String) -> CGKeyCode? {
        switch key {
        case ",": return 43
        case ".": return 47
        case "Return", "\n": return 36
        case "Tab", "\t": return 48
        case "Space", " ": return 49
        case "Escape": return 53
        case "ArrowLeft": return 123
        case "ArrowRight": return 124
        case "ArrowDown": return 125
        case "ArrowUp": return 126
        default:
            // single-character a-z mapping
            if key.count == 1, let scalar = key.lowercased().unicodeScalars.first,
               scalar.value >= 0x61, scalar.value <= 0x7A {
                let order: [CGKeyCode] = [
                    0, 11, 8, 2, 14, 3, 5, 4, 34, 38, // a..j
                    40, 37, 46, 45, 31, 35, 12, 15, 1, 17, // k..t
                    32, 9, 13, 7, 16, 6 // u..z
                ]
                return order[Int(scalar.value - 0x61)]
            }
            return nil
        }
    }
}
