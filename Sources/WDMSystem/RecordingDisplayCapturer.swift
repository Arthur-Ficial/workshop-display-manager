import Foundation

/// File-backed recording capturer for hermetic CLI tests. Writes one line per
/// `capture` and `release` call to the file at `url`. Never touches a real display.
public final class RecordingDisplayCapturer: DisplayCapturer, @unchecked Sendable {
    private let url: URL

    public init(url: URL) { self.url = url }

    public func capture(_ id: UInt32) throws { try append("capture id=\(id)\n") }
    public func release(_ id: UInt32) throws { try append("release id=\(id)\n") }

    private func append(_ line: String) throws {
        let data = Data(line.utf8)
        if FileManager.default.fileExists(atPath: url.path) {
            let h = try FileHandle(forWritingTo: url)
            defer { try? h.close() }
            try h.seekToEnd()
            try h.write(contentsOf: data)
        } else {
            try data.write(to: url)
        }
    }
}
