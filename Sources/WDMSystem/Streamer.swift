import Foundation

/// Live network broadcast of a display. Real impl shells out to `ffmpeg`
/// (`-f avfoundation` capture → `-c:v h264_videotoolbox` encode →
/// `-f hls` or `-f flv`). Recording impl logs every call for hermetic
/// tests.
public protocol Streamer: Sendable {
    /// Stream `displayID` for `durationSec` seconds. `target` is either an
    /// `rtmp://...` URL or a local directory path (for HLS).
    /// `mode` selects between HLS-to-dir and RTMP-push semantics.
    func stream(
        displayID: UInt32, target: String, mode: StreamMode, durationSec: Int
    ) throws
}

public enum StreamMode: String, Sendable, Codable, Equatable {
    case hls
    case rtmp
}
