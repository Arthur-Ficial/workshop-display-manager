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
        // Critical for Liquid Glass: window must be transparent so glass
        // surfaces inside (`.glassEffect`, `.containerBackground(_:for:.window)`)
        // can blur the desktop and adjacent windows. An opaque window means
        // glass blurs nothing → looks like a flat tinted material.
        win.isOpaque = false
        win.backgroundColor = .clear
        win.contentView = host
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
