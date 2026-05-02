import Foundation
import WDMCore

public final class ProfileStore: @unchecked Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func resolve(env: [String: String]) -> ProfileStore {
        if let p = env["WDM_PROFILES_DIR"], !p.isEmpty {
            return ProfileStore(directory: URL(fileURLWithPath: p))
        }
        let home = (env["HOME"]).map(URL.init(fileURLWithPath:))
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return ProfileStore(
            directory: home.appendingPathComponent(".config/wdm/profiles")
        )
    }

    private func ensureDir() throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
    }

    private func url(for name: String) -> URL {
        directory.appendingPathComponent("\(name).json")
    }

    public func save(name: String, snapshot: Snapshot) throws {
        try ensureDir()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url(for: name), options: .atomic)
    }

    public func load(name: String) throws -> Snapshot {
        let path = url(for: name)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw CLIError.profileNotFound(name)
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(Snapshot.self, from: data)
    }

    public func list() -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        return entries
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(".json".count)) }
            .sorted()
    }

    /// Delete a profile by name. Throws `profileNotFound` if it doesn't exist
    /// (single source of truth — never lies about success).
    public func remove(name: String) throws {
        let path = url(for: name)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw CLIError.profileNotFound(name)
        }
        try FileManager.default.removeItem(at: path)
    }
}
