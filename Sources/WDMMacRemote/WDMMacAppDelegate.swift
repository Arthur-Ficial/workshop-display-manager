import Foundation
import AppKit
import SwiftUI
import Combine
import WDMMac
import WDMRemoteControl

/// Owns the headed-mode lifecycle: builds the main window, attaches it to
/// the AccessibilityWalker, optionally starts the remote API, and pushes
/// AppearanceStore changes to NSWindow.appearance live.
@MainActor
final class WDMMacAppDelegate: NSObject, NSApplicationDelegate {
    let runtime: MacRuntime
    let args: MacArgs
    var window: NSWindow?
    var settingsWindow: NSWindow?
    private var server: RemoteControlServer?
    private var appearanceSink: AnyCancellable?

    init(runtime: MacRuntime, args: MacArgs) {
        self.runtime = runtime
        self.args = args
    }

    var appearance: AppearanceStore { runtime.deps.appearance }
    var adapter: WDMMacRemoteAdapter { runtime.adapter }
    var vm: DisplaysListVM { runtime.vm }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let win = WDMMacMainWindowFactory.make(vm: vm, appearance: appearance)
        win.makeKeyAndOrderFront(nil)
        window = win
        // Skipping `adapter.attach(window:)` — the embedded WebKit Stage
        // makes the AX-walker path unsafe (synchronous IPC into WebKit's
        // child process trips the Swift 6 actor-isolation runtime check
        // when called from the network queue's main-sync hop). Snapshot
        // returns registry-only entries; native SwiftUI controls drop
        // off the agent surface in headed mode for now. The WDMMac
        // module's own e2e tests (HeadedSnapshotCoverageTests etc.) are
        // gated behind WDM_HEADED_E2E=1 and not run by default.

        appearanceSink = appearance.$mode.sink { [weak self] new in
            self?.window?.appearance = new.nsAppearance
            self?.settingsWindow?.appearance = new.nsAppearance
        }

        WDMMacAppMenu.installSettings(target: self,
                                      action: #selector(openSettings))

        if args.remote { startRemote() }
    }

    @objc func openSettings() {
        if let w = settingsWindow { w.makeKeyAndOrderFront(nil); return }
        let w = WDMMacSettingsWindowFactory.make(appearance: appearance)
        w.makeKeyAndOrderFront(nil)
        settingsWindow = w
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
            let path = remoteStatePath()
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
        RemoteStateWriter.clear(at: remoteStatePath())
    }

    private func remoteStatePath() -> URL {
        args.statePath.map(URL.init(fileURLWithPath:)) ?? RemoteStateWriter.defaultPath()
    }
}
