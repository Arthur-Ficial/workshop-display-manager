import Foundation
import WDMCore

/// File-backed recording flipper for hermetic CLI tests.
/// Writes one line per `run` to the file at `url`:
///   `run displayID=<id> flip=<axis> durationMs=<N|nil>`
/// then sleeps for `durationMs` (or returns immediately if nil).
/// `stop` writes `stop` to the same file.
public final class RecordingOverlayFlipper: OverlayFlipper, @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var stopRequested = false
    /// When non-nil, `run(...)` throws `ProviderError.configurationFailed`
    /// with this message before recording — used to test caller
    /// honest-unsupported-path surfacing of permission denials.
    private let throwMessage: String?

    public init(url: URL, throwMessage: String? = nil) {
        self.url = url
        self.throwMessage = throwMessage
    }

    public func run(displayID: UInt32, flip: Flip, durationMs: Int?) throws {
        if let msg = throwMessage {
            throw ProviderError.configurationFailed(msg)
        }
        let line = "run displayID=\(displayID) flip=\(flip.rawValue) durationMs=\(durationMs.map(String.init) ?? "nil")\n"
        try append(line)
        if let ms = durationMs {
            Thread.sleep(forTimeInterval: TimeInterval(ms) / 1000.0)
        } else {
            // Without a duration the production overlay blocks until SIGINT.
            // For the recording flipper we still poll so tests that expect
            // the call to "block" can drive `stop()` from the outside.
            while !stopFlagged() { Thread.sleep(forTimeInterval: 0.01) }
        }
    }

    public func stop() {
        try? append("stop\n")
        lock.withLock { stopRequested = true }
    }

    private func stopFlagged() -> Bool { lock.withLock { stopRequested } }

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
