import Foundation
import WDMSystem

public struct CLIDeps: Sendable {
    public let provider: DisplayProvider
    public let profileStore: ProfileStore
    public let confirmer: Confirmer
    public let nativeConfirmer: Confirmer
    public let eventStream: DisplayEventStream
    public let overlayFlipper: OverlayFlipper
    public let pipFlipper: PipFlipper
    public let sleeper: Sleeper
    public let displayCapturer: DisplayCapturer
    public let virtualDisplayManager: VirtualDisplayManager
    public let screenshotter: Screenshotter
    public let recorder: Recorder
    public let windowMover: WindowMover
    public let processEnv: [String: String]
    public let stdout: OutputWriter
    public let stderr: OutputWriter

    public init(
        provider: DisplayProvider,
        profileStore: ProfileStore,
        confirmer: Confirmer,
        nativeConfirmer: Confirmer,
        eventStream: DisplayEventStream,
        overlayFlipper: OverlayFlipper,
        pipFlipper: PipFlipper,
        sleeper: Sleeper,
        displayCapturer: DisplayCapturer,
        virtualDisplayManager: VirtualDisplayManager,
        screenshotter: Screenshotter,
        recorder: Recorder,
        windowMover: WindowMover,
        processEnv: [String: String],
        stdout: OutputWriter,
        stderr: OutputWriter
    ) {
        self.provider = provider
        self.profileStore = profileStore
        self.confirmer = confirmer
        self.nativeConfirmer = nativeConfirmer
        self.eventStream = eventStream
        self.overlayFlipper = overlayFlipper
        self.pipFlipper = pipFlipper
        self.sleeper = sleeper
        self.displayCapturer = displayCapturer
        self.virtualDisplayManager = virtualDisplayManager
        self.screenshotter = screenshotter
        self.recorder = recorder
        self.windowMover = windowMover
        self.processEnv = processEnv
        self.stdout = stdout
        self.stderr = stderr
    }
}
