import Foundation

/// File-backed recording streamer for hermetic CLI tests. Logs every call
/// — including the full StreamOptions payload — and never spawns capture.
public final class RecordingStreamer: Streamer, @unchecked Sendable {
    private let logURL: URL

    public init(logURL: URL) { self.logURL = logURL }

    public func stream(
        displayID: UInt32, target: String, mode: StreamMode,
        durationSec: Int, options: StreamOptions
    ) throws {
        var line = "stream"
        line += " displayID=\(displayID)"
        line += " mode=\(mode.rawValue)"
        line += " target=\(target)"
        line += " durationSec=\(durationSec)"
        line += " segmentDurationSec=\(options.segmentDurationSec)"
        line += " framerate=\(options.framerate)"
        line += " showCursor=\(options.showCursor)"
        if let kbps = options.bitrateKbps {
            line += " bitrateKbps=\(kbps)"
        }
        line += "\n"
        let data = Data(line.utf8)
        if FileManager.default.fileExists(atPath: logURL.path) {
            let h = try FileHandle(forWritingTo: logURL)
            defer { try? h.close() }
            try h.seekToEnd()
            try h.write(contentsOf: data)
        } else {
            try data.write(to: logURL)
        }
    }
}
