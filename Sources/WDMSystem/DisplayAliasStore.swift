import Foundation
import WDMCore

/// Persistent store of friendly per-display aliases. Two key kinds:
///   - `edid:<stableID>` — preferred, survives reboot/replug
///   - `id:<displayID>`  — fallback for displays without EDID
///
/// File format is `~/.config/wdm/aliases.json` (or `WDM_ALIASES_FILE` env).
public final class DisplayAliasStore: @unchecked Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static func resolve(env: [String: String]) -> DisplayAliasStore {
        if let p = env["WDM_ALIASES_FILE"], !p.isEmpty {
            return DisplayAliasStore(url: URL(fileURLWithPath: p))
        }
        let home = (env["HOME"]).map(URL.init(fileURLWithPath:))
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return DisplayAliasStore(
            url: home.appendingPathComponent(".config/wdm/aliases.json")
        )
    }

    public func load() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    public func save(_ aliases: [String: String]) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(aliases)
        try data.write(to: url, options: .atomic)
    }

    public func upsert(key: String, name: String) throws {
        var current = try load()
        current[key] = name
        try save(current)
    }

    @discardableResult
    public func remove(key: String) throws -> Bool {
        var current = try load()
        guard current.removeValue(forKey: key) != nil else { return false }
        try save(current)
        return true
    }

    /// Best alias for a display: prefer EDID-keyed, fall back to id-keyed.
    public func alias(forID id: UInt32, edidStableID: String?) throws -> String? {
        let map = try load()
        if let s = edidStableID, let n = map["edid:\(s)"] { return n }
        return map["id:\(id)"]
    }

    public static func key(forID id: UInt32, edidStableID: String?) -> String {
        if let s = edidStableID { return "edid:\(s)" }
        return "id:\(id)"
    }
}
