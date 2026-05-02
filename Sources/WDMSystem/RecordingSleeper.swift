import Foundation

/// File-backed recording sleeper for hermetic CLI tests. Writes one line
/// per `sleepNow()` call to the file at `url`. Never actually sleeps the Mac.
public final class RecordingSleeper: Sleeper {
    private let url: URL

    public init(url: URL) { self.url = url }

    public func sleepNow() throws {
        let line = "sleepNow\n"
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
