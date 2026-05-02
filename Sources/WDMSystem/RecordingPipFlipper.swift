import Foundation
import WDMCore

/// File-backed recording PIP flipper for hermetic CLI tests. Writes a single
/// line per `run` call to the file at `url` with all arguments, then sleeps
/// for `durationMs` (or polls until `stop()` for nil).
public final class RecordingPipFlipper: PipFlipper, @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var stopRequested = false

    public init(url: URL) { self.url = url }

    public func run(
        sourceID: UInt32,
        destinationID: UInt32,
        size: PipSize,
        position: PipPosition?,
        flip: Flip,
        durationMs: Int?
    ) throws {
        let posTag = position.map { "\($0.x),\($0.y)" } ?? "centered"
        let line =
            "run source=\(sourceID) destination=\(destinationID) " +
            "size=\(size.width)x\(size.height) " +
            "position=\(posTag) " +
            "flip=\(flip.rawValue) " +
            "durationMs=\(durationMs.map(String.init) ?? "nil")\n"
        try append(line)
        if let ms = durationMs {
            Thread.sleep(forTimeInterval: TimeInterval(ms) / 1000.0)
        } else {
            while !stopFlagged() { Thread.sleep(forTimeInterval: 0.01) }
        }
    }

    public func stop() {
        try? append("stop\n")
        lock.withLock { stopRequested = true }
    }

    private func stopFlagged() -> Bool { lock.withLock { stopRequested } }

    private func append(_ line: String) throws {
        // Serialize append across concurrent callers — pip-grid + Task.detached
        // produces N parallel writers to the same log file; without the lock,
        // both can take the "file doesn't exist" branch and overwrite.
        try lock.withLock {
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
}
