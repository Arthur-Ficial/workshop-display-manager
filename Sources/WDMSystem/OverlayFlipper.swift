import Foundation
import WDMCore

/// Software flip: opens a borderless overlay window on the target display
/// that mirrors the underlying display content through a flipping transform.
/// Unlike `setFlip` (framebuffer-level, IOKit), this works on every Mac
/// including Apple Silicon, AirPlay, and Sidecar — at the cost of running
/// a foreground process that holds the window for the duration of use.
public protocol OverlayFlipper: Sendable {
    /// Open the overlay on `displayID` with `flip` applied. Blocks the
    /// calling thread until `stop()` is invoked from another thread or the
    /// run-loop terminates. Throws if the display is unknown or capture is
    /// refused (Screen Recording permission missing).
    func run(displayID: UInt32, flip: Flip, durationMs: Int?) throws

    /// Request the overlay to tear down. Safe to call from any thread.
    func stop()
}
