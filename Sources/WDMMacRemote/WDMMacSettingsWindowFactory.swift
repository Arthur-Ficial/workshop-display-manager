import Foundation
import AppKit
import SwiftUI
import WDMMac

/// Builds the Settings NSWindow that hosts `SettingsView`.
@MainActor
enum WDMMacSettingsWindowFactory {
    static func make(appearance: AppearanceStore) -> NSWindow {
        let view = SettingsView(appearance: appearance)
        let host = NSHostingView(rootView: view)
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        w.title = "Settings"
        w.contentView = host
        w.appearance = appearance.mode.nsAppearance
        w.center()
        return w
    }
}
