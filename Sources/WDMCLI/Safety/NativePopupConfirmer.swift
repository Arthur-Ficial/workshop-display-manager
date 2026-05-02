import Foundation
import AppKit

/// Mac-native confirmation popup with a live countdown. Activated by `--confirm`.
///
/// Behaviour:
///   - Opens a floating, key-grabbing window with a label.
///   - Label updates every second: "Keep change? SPACE to confirm, any other key
///     to cancel.  Reverting in 15s..." then 14, 13, …
///   - SPACE → returns true (keep).
///   - Any other key → returns false (cancel/revert).
///   - Timer reaching 0 → returns false (timeout/revert).
///
/// Implemented with a manual `NSApp.nextEvent` pump so we don't have to wrestle
/// with `@Sendable` Timer callbacks under Swift 6 strict concurrency. AppKit is
/// main-thread-only; we hop to the main thread when called from elsewhere.
public final class NativePopupConfirmer: Confirmer, @unchecked Sendable {
    public init() {}

    public func confirm(timeoutSeconds: Int) -> Bool {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { self.runOnMain(timeout: timeoutSeconds) }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { self.runOnMain(timeout: timeoutSeconds) }
        }
    }

    @MainActor
    private func runOnMain(timeout: Int) -> Bool {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let frame = NSRect(x: 0, y: 0, width: 460, height: 140)
        let window = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = "wdm — confirm display change"
        window.level = .floating
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = false
        window.center()

        let label = NSTextField(labelWithString: "")
        label.frame = NSRect(x: 20, y: 20, width: 420, height: 100)
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        window.contentView?.addSubview(label)

        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)

        defer {
            window.orderOut(nil)
            window.close()
        }

        let start = Date()
        var lastShown = -1
        while true {
            let elapsed = Int(Date().timeIntervalSince(start))
            let remaining = timeout - elapsed
            if remaining <= 0 { return false }
            if remaining != lastShown {
                lastShown = remaining
                label.stringValue = """
                Keep this display change?

                Press SPACE to confirm, any other key to cancel.
                Reverting automatically in \(remaining)s…
                """
            }

            let until = Date().addingTimeInterval(0.1)
            if let event = app.nextEvent(matching: .any, until: until, inMode: .default, dequeue: true) {
                if event.type == .keyDown {
                    return event.keyCode == 49   // 49 = space
                }
                app.sendEvent(event)
            }
        }
    }
}
