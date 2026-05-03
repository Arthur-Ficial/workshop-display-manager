import Foundation
import WDMKit

/// Builds a `WDMController` plus the effects WDMWeb needs from the same env
/// the CLI uses. Honours `WDM_TEST_FIXTURE` for hermetic tests.
public enum WDMWebControllerFactory {
    public static func make(env: [String: String]) throws -> WDMWebDeps {
        let provider = try DisplayProviderFactory.make(env: env)
        let profileStore = ProfileStore.resolve(env: env)
        return WDMWebDeps(
            controller: WDMController(provider: provider, profileStore: profileStore, env: env),
            provider: provider,
            screenshotter: ScreenshotterFactory.make(env: env),
            recorder: RecorderFactory.make(env: env),
            pipFlipper: PipFlipperFactory.make(env: env),
            displayCapturer: DisplayCapturerFactory.make(env: env),
            cursorTracker: CursorTrackerFactory.make(env: env),
            virtualDisplayManager: VirtualDisplayManagerFactory.make(env: env),
            sleeper: SleeperFactory.make(env: env),
            ddcProvider: DDCProviderFactory.make(env: env),
            hdrProvider: HDRProviderFactory.make(env: env),
            env: env
        )
    }
}

/// Effect bundle WDMWeb passes to handlers. Mirrors `CLIDeps` but only the
/// bits handlers actually use — no stdout/stderr writers, no confirmers.
public struct WDMWebDeps: Sendable {
    public let controller: WDMController
    public let provider: DisplayProvider
    public let screenshotter: Screenshotter
    public let recorder: Recorder
    public let pipFlipper: PipFlipper
    public let displayCapturer: DisplayCapturer
    public let cursorTracker: CursorTracker
    public let virtualDisplayManager: VirtualDisplayManager
    public let sleeper: Sleeper
    public let ddcProvider: DDCProvider
    public let hdrProvider: HDRProvider
    public let env: [String: String]
}
