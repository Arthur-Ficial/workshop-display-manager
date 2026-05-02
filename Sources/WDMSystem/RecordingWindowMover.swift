import Foundation

/// File-backed recording window mover for hermetic CLI tests. Logs every
/// call; never touches the AX API.
public final class RecordingWindowMover: WindowMover, @unchecked Sendable {
    private let logURL: URL

    public init(logURL: URL) { self.logURL = logURL }

    public func move(pattern: String, displayID: UInt32) throws {
        let line = "move pattern=\(pattern) displayID=\(displayID)\n"
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
