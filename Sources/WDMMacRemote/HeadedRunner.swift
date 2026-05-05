import Foundation
import AppKit
import WDMMac
import WDMRemoteControl

/// Headed mode entry point. Opens an NSWindow with the SwiftUI app, optionally
/// also starts the remote API server. All wiring lives in `WDMMacAppDelegate`
/// and the helpers it composes (one job per file).
public enum HeadedRunner {
    @MainActor
    public static func run(args: MacArgs) throws -> Never {
        let runtime = try MacRuntime.make()
        // NSApplication.delegate is weak — keep a strong local until app.run()
        // returns, otherwise the delegate is freed before launch fires.
        let delegate = WDMMacAppDelegate(runtime: runtime, args: args)
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        app.run()
        _ = delegate
        exit(0)
    }
}
