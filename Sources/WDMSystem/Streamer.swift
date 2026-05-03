import Foundation

/// Live network broadcast of a display via HLS (filesystem segments) or
/// RTMP (push to URL). The native impl uses ScreenCaptureKit + AVAssetWriter
/// with the mpeg4AppleHLS profile; the recording impl logs every call for
/// hermetic CLI tests.
public protocol Streamer: Sendable {
    /// Stream `displayID` for `durationSec` seconds.
    /// `target` is either an `rtmp://...` URL or a local directory path (HLS).
    /// `mode` selects between HLS-to-dir and RTMP-push semantics.
    /// `options` carries every tunable knob (framerate, segment duration, …).
    func stream(
        displayID: UInt32, target: String, mode: StreamMode,
        durationSec: Int, options: StreamOptions
    ) throws
}

public enum StreamMode: String, Sendable, Codable, Equatable {
    case hls
    case rtmp
}

/// Configurable knobs for `Streamer.stream`. Validated at the CLI boundary.
public struct StreamOptions: Equatable, Sendable {
    public let segmentDurationSec: Int
    public let framerate: Int
    public let showCursor: Bool
    public let bitrateKbps: Int?

    public init(
        segmentDurationSec: Int = 2,
        framerate: Int = 30,
        showCursor: Bool = true,
        bitrateKbps: Int? = nil
    ) {
        self.segmentDurationSec = segmentDurationSec
        self.framerate = framerate
        self.showCursor = showCursor
        self.bitrateKbps = bitrateKbps
    }

    public static let `default` = StreamOptions()
}
