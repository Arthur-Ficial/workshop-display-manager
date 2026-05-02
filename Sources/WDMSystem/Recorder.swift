import Foundation

/// Record a single display's framebuffer to a video file. Real impl shells
/// out to `/usr/sbin/screencapture -v -V <seconds> -D <idx>`, which uses
/// ScreenCaptureKit internally and works for every display macOS knows about
/// — real, virtual, AirPlay, Sidecar.
///
/// Output container is `.mov` (QuickTime) by default. macOS records H.264 +
/// VideoToolbox-encoded; convert to mp4/mkv with ffmpeg if needed
/// (out of scope for this verb — single responsibility).
public protocol Recorder: Sendable {
    /// Record `displayID` for `durationSec` seconds, writing to `url`.
    /// Blocks the calling thread until the recording completes. Throws
    /// `displayNotFound` for unknown ids and `ioError` on write failure.
    func record(displayID: UInt32, to url: URL, durationSec: Int) throws
}
