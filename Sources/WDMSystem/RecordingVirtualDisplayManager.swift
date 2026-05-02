import Foundation
import WDMCore

/// File-backed recording manager for hermetic CLI tests. Writes one line per
/// `run` to the file at `url`:
///   `run name=<n> <W>x<H>@<Hz> hiDPI=<bool> durationMs=<N|nil>`
/// Then either sleeps for `durationMs` or polls until `stop()`. Never touches
/// CoreGraphics. Mirrors `RecordingOverlayFlipper`.
public final class RecordingVirtualDisplayManager: VirtualDisplayManager, @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var stopRequested = false

    public init(url: URL) { self.url = url }

    public func run(spec: VirtualDisplaySpec, durationMs: Int?) throws {
        let line =
            "run name=\(spec.name) \(spec.width)x\(spec.height)@\(spec.refreshHz) " +
            "hiDPI=\(spec.hiDPI) " +
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
