import Foundation

/// Hermetic recording impl. Logs the call and writes a tiny QuickTime-shaped
/// placeholder file so test callers can verify the output path was written.
public final class RecordingRecorder: Recorder, @unchecked Sendable {
    private let logURL: URL

    public init(logURL: URL) { self.logURL = logURL }

    public func record(displayID: UInt32, to url: URL, durationSec: Int) throws {
        let line = "record displayID=\(displayID) out=\(url.path) durationSec=\(durationSec)\n"
        try append(line)
        // 24-byte minimal MOV "ftyp" box stand-in. Tests check the file exists,
        // not the codec — production verification covers the real shape.
        let placeholder = Data([
            0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70,
            0x71, 0x74, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00,
            0x71, 0x74, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00,
        ])
        try placeholder.write(to: url)
    }

    private func append(_ line: String) throws {
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
