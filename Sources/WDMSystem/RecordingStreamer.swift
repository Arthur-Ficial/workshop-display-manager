import Foundation

/// File-backed recording streamer for hermetic CLI tests. Logs every call;
/// never spawns ffmpeg.
public final class RecordingStreamer: Streamer, @unchecked Sendable {
    private let logURL: URL

    public init(logURL: URL) { self.logURL = logURL }

    public func stream(
        displayID: UInt32, target: String, mode: StreamMode, durationSec: Int
    ) throws {
        let line = "stream displayID=\(displayID) mode=\(mode.rawValue) target=\(target) durationSec=\(durationSec)\n"
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
