import Foundation

/// Capture a single display's framebuffer to a PNG file. Real impl uses
/// `SCScreenshotManager.captureImage` (the macOS 14+ public successor to the
/// obsoleted `CGDisplayCreateImage`). Recording impl writes a tiny placeholder
/// PNG so hermetic e2e tests can still assert "the file exists and is a PNG."
public protocol Screenshotter: Sendable {
    func capture(displayID: UInt32, to url: URL) throws
}
