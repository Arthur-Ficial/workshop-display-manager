import Foundation

/// Test-only `DDCProvider`. Reads come from the fixture file's `ddc` map;
/// writes are appended to `WDM_TEST_DDC_LOG`. The fixture-file URL must
/// match the same one given to `FixtureDisplayProvider` so reads stay
/// consistent across `wdm ddc get` calls within a single test.
public final class RecordingDDCProvider: DDCProvider, @unchecked Sendable {
    private let fixtureURL: URL
    private let logURL: URL
    private let queue = DispatchQueue(label: "wdm.test.ddc.recording")

    public init(fixtureURL: URL, logURL: URL) {
        self.fixtureURL = fixtureURL
        self.logURL = logURL
        // Truncate so prior runs don't bleed in.
        try? "".write(to: logURL, atomically: true, encoding: .utf8)
    }

    public func read(displayID: UInt32, vcp: UInt8) throws -> UInt16 {
        try queue.sync {
            let map = try loadDDCMap()
            guard let perDisplay = map[String(displayID)] else {
                throw DDCError.unsupported(displayID)
            }
            // VCP codes stored as decimal strings to keep JSON portable.
            return UInt16(perDisplay[String(vcp)] ?? 0)
        }
    }

    public func write(displayID: UInt32, vcp: UInt8, value: UInt16) throws {
        try queue.sync {
            let map = try loadDDCMap()
            guard map[String(displayID)] != nil else {
                throw DDCError.unsupported(displayID)
            }
            let line = String(
                format: "write display=%d vcp=0x%02X value=%d\n",
                displayID, vcp, value
            )
            append(line)
        }
    }

    private func loadDDCMap() throws -> [String: [String: Int]] {
        let data = try Data(contentsOf: fixtureURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["ddc"] as? [String: [String: Int]] else {
            return [:]
        }
        return raw
    }

    private func append(_ line: String) {
        let data = Data(line.utf8)
        if let h = try? FileHandle(forWritingTo: logURL) {
            defer { try? h.close() }
            do {
                try h.seekToEnd()
                try h.write(contentsOf: data)
            } catch {
                try? line.write(to: logURL, atomically: true, encoding: .utf8)
            }
        } else {
            try? line.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }
}
