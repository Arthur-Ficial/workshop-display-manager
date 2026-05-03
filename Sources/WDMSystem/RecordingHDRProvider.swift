import Foundation

/// Hermetic test impl of `HDRProvider`. Reads/writes a JSON file at the
/// fixture URL (sharing the same file as `FixtureDisplayProvider`).
/// Writes are also appended to `WDM_TEST_HDR_LOG` for assertion.
public final class RecordingHDRProvider: HDRProvider, @unchecked Sendable {
    private let fixtureURL: URL
    private let logURL: URL
    private let queue = DispatchQueue(label: "wdm.test.hdr.recording")

    public init(fixtureURL: URL, logURL: URL) {
        self.fixtureURL = fixtureURL
        self.logURL = logURL
        try? "".write(to: logURL, atomically: true, encoding: .utf8)
    }

    public func isHDREnabled(displayID: UInt32) throws -> Bool? {
        try queue.sync {
            let map = try loadHDRMap()
            return map[String(displayID)]
        }
    }

    public func setHDR(displayID: UInt32, enabled: Bool) throws {
        try queue.sync {
            var root = try loadRoot()
            var map: [String: Bool] = (root["hdr"] as? [String: Bool]) ?? [:]
            guard map[String(displayID)] != nil else {
                throw HDRError.unsupported(displayID)
            }
            map[String(displayID)] = enabled
            root["hdr"] = map
            let data = try JSONSerialization.data(
                withJSONObject: root, options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: fixtureURL, options: .atomic)
            append("set display=\(displayID) hdr=\(enabled ? "on" : "off")\n")
        }
    }

    private func loadRoot() throws -> [String: Any] {
        let data = try Data(contentsOf: fixtureURL)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func loadHDRMap() throws -> [String: Bool] {
        let root = try loadRoot()
        return (root["hdr"] as? [String: Bool]) ?? [:]
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
