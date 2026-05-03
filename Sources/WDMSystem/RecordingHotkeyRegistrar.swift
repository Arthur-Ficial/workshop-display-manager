import Foundation

/// Hermetic test impl of `HotkeyRegistrar`. Writes every `register` call
/// to a log file (`WDM_TEST_HOTKEYS_LOG`); on `run` it consumes the
/// pre-loaded `WDM_TEST_HOTKEYS_FIRE` chord(s) and synthesises events.
public final class RecordingHotkeyRegistrar: HotkeyRegistrar, @unchecked Sendable {
    private let logURL: URL
    private let fireChords: [String]
    private let queue = DispatchQueue(label: "wdm.test.hotkey.registrar")
    private var registered: Set<String> = []

    public init(logURL: URL, fireChords: [String]) {
        self.logURL = logURL
        self.fireChords = fireChords
        // Truncate at the start of the test so prior runs don't leak.
        try? "".write(to: logURL, atomically: true, encoding: .utf8)
    }

    public func register(chord: String) throws {
        queue.sync {
            registered.insert(chord)
            append("register \(chord)\n")
        }
    }

    public func run(maxEvents: Int?, onFire: @escaping (String) -> Void) {
        let cap = maxEvents ?? Int.max
        var fired = 0
        for chord in fireChords {
            if fired >= cap { break }
            // Only fire chords the daemon actually registered — mirrors real OS behaviour.
            if registered.contains(chord) {
                onFire(chord)
                fired += 1
            }
        }
    }

    private func append(_ line: String) {
        let data = Data(line.utf8)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                // File-handle append failed; fall back to overwrite (best-effort).
                try? line.write(to: logURL, atomically: true, encoding: .utf8)
            }
        } else {
            try? line.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }
}
