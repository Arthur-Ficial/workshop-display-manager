import Foundation
import AppKit
import SwiftUI
import WDMMac
import WDMRemoteControl

/// Headed mode: open an NSWindow with the SwiftUI ContentView. Optionally
/// also start the remote API server (when `--remote` is passed). Hand-rolled
/// NSApplication setup so the same module can run --headless without ever
/// touching a window.
public enum HeadedRunner {
    @MainActor
    public static func run(args: MacArgs) throws -> Never {
        let deps = try WDMMacAppDeps.make()
        let registry = RemoteRegistry()
        let adapter = WDMMacRemoteAdapter(registry: registry)

        let app = NSApplication.shared
        let delegate = WDMMacAppDelegate(deps: deps, registry: registry,
                                         adapter: adapter, args: args)
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        app.run()
        exit(0)
    }
}

@MainActor
final class WDMMacAppDelegate: NSObject, NSApplicationDelegate {
    let deps: WDMMacAppDeps
    let registry: RemoteRegistry
    let adapter: WDMMacRemoteAdapter
    let args: MacArgs
    var window: NSWindow?
    var server: RemoteControlServer?
    var runner: WDMMacRemoteRunner?
    var vm: DisplaysListVM?

    init(deps: WDMMacAppDeps, registry: RemoteRegistry,
         adapter: WDMMacRemoteAdapter, args: MacArgs) {
        self.deps = deps; self.registry = registry
        self.adapter = adapter; self.args = args
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vm = DisplaysListVM(controller: deps.controller)
        vm.reload()
        let runner = WDMMacRemoteRunner(registry: registry, vm: vm)
        self.vm = vm
        self.runner = runner
        let content = ContentView(vm: vm) { remoteID in vm.select(remoteID: remoteID) }
        let host = NSHostingView(rootView: content)
        let win = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        win.title = "Workshop Display Manager"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .visible
        win.isMovableByWindowBackground = true

        // Tahoe Liquid Glass for a manually-created NSWindow:
        //   - Window is transparent (isOpaque=false, backgroundColor=clear)
        //   - An NSVisualEffectView with material=.windowBackground +
        //     blendingMode=.behindWindow paints the system's frosted backdrop
        //     blurring the desktop & windows behind it.
        //   - On macOS 26 the system promotes this material to real Liquid
        //     Glass automatically; on macOS 13–15 it's the legacy material.
        //   - The SwiftUI content sits in front; inner `.glassEffect()` calls
        //     in WDMMac chrome layer additional Liquid Glass on top.
        win.isOpaque = false
        win.backgroundColor = .clear
        // SwiftUI's .frame(minWidth:minHeight:) doesn't propagate to NSWindow
        // when hosted via NSHostingView, so set the constraint explicitly.
        win.contentMinSize = NSSize(width: 520, height: 360)

        // Half-transparent Liquid Glass backdrop. Per cmux issue #2459 and the
        // Apple Developer Forum thread on transparent SwiftUI windows:
        // NSGlassEffectView is currently buggy with hosted SwiftUI content
        // (blank / incorrectly tinted). The reliable path on macOS 26 is
        // NSVisualEffectView with `material = .sidebar` (more translucent
        // than .windowBackground) and `blendingMode = .behindWindow` — that
        // pulls pixels from the desktop & windows behind, giving the proper
        // see-through-frosted look that on Tahoe gets the system's Liquid
        // Glass treatment automatically.
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
        win.contentView = vfx
        win.makeKeyAndOrderFront(nil)
        self.window = win

        if args.remote { startRemote() }
    }

    private func startRemote() {
        do {
            let s = try RemoteControlServer(port: args.port, target: adapter)
            s.runAsync()
            let port = s.resolvedPort() ?? args.port
            let state = RemoteState(port: port,
                                    pid: ProcessInfo.processInfo.processIdentifier,
                                    startedAt: Date(),
                                    version: "wdm-mac/0.1")
            let path = args.statePath.map(URL.init(fileURLWithPath:))
                ?? RemoteStateWriter.defaultPath()
            try RemoteStateWriter.write(state, to: path)
            FileHandle.standardError.write(Data(
                "wdm-mac --remote: listening on 127.0.0.1:\(port) (state: \(path.path))\n".utf8
            ))
            self.server = s
        } catch {
            FileHandle.standardError.write(Data("wdm-mac --remote: failed: \(error)\n".utf8))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
        if let path = (args.statePath.map(URL.init(fileURLWithPath:))
                       ?? Optional(RemoteStateWriter.defaultPath())) {
            RemoteStateWriter.clear(at: path)
        }
    }
}
