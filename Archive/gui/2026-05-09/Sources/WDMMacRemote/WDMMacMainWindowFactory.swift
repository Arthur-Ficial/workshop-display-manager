import Foundation
import AppKit
import SwiftUI
import WDMMac

/// Builds the main "Workshop Display Manager" NSWindow with the system's
/// frosted backdrop (NSVisualEffectView .sidebar / .behindWindow), and
/// hosts the SwiftUI `AppFrameView` inside.
@MainActor
enum WDMMacMainWindowFactory {
    static let title = "Workshop Display Manager"

    static func make(vm: DisplaysListVM, appearance: AppearanceStore) -> NSWindow {
        let content = AppFrameView(vm: vm) { remoteID in vm.select(remoteID: remoteID) }
        let host = NSHostingView(rootView: content)
        let win = NSWindow(
            contentRect: NSRect(x: 160, y: 160, width: 1100, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        configureChrome(win, appearance: appearance)
        win.contentView = makeBackdrop(hosting: host)
        return win
    }

    private static func configureChrome(_ win: NSWindow, appearance: AppearanceStore) {
        win.title = title
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .visible
        win.isRestorable = false
        // titlebarSeparatorStyle=.line is invisible against a transparent
        // title chrome — the system paints the line into the transparent
        // zone where it disappears. The visible separator is added by
        // AppFrameView as a SwiftUI Rectangle at the top of the safe area.
        // isMovableByWindowBackground was true; that lets AppKit start a
        // window-drag from anywhere in the content area, which forces every
        // SwiftUI Button to delay press detection waiting to see if the
        // user is dragging. The result was sluggish, sometimes-missing
        // clicks (tabs especially). Standard titlebar chrome still
        // provides the drag handle, so dropping it costs nothing.
        win.isMovableByWindowBackground = false
        win.appearance = appearance.mode.nsAppearance
        // Tahoe Liquid Glass needs a transparent NSWindow so the
        // NSVisualEffectView inside can pull pixels from behind.
        win.isOpaque = false
        win.backgroundColor = .clear
        // SwiftUI's .frame(minWidth:minHeight:) doesn't bind to NSWindow when
        // hosted via NSHostingView — set the constraint explicitly.
        win.contentMinSize = NSSize(width: 920, height: 560)
        win.setContentSize(NSSize(width: 1100, height: 680))
    }

    private static func makeBackdrop(hosting host: NSHostingView<AppFrameView>) -> NSView {
        // NSVisualEffectView with .sidebar / .behindWindow is the reliable
        // path on macOS 26 — NSGlassEffectView is buggy with hosted SwiftUI.
        let vfx = NSVisualEffectView()
        vfx.material = .sidebar
        vfx.blendingMode = .behindWindow
        vfx.state = .active
        host.translatesAutoresizingMaskIntoConstraints = false
        vfx.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: vfx.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: vfx.trailingAnchor),
            host.topAnchor.constraint(equalTo: vfx.topAnchor),
            host.bottomAnchor.constraint(equalTo: vfx.bottomAnchor),
        ])
        return vfx
    }
}
