import Foundation
import WDMCore

/// JSON-on-disk store for user keybindings.
/// Default path: `~/.config/wdm/keybindings.json`.
/// Override via `WDM_KEYBINDINGS_FILE` (used by tests).
public final class KeybindingStore: @unchecked Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static func resolve(env: [String: String]) -> KeybindingStore {
        if let p = env["WDM_KEYBINDINGS_FILE"], !p.isEmpty {
            return KeybindingStore(url: URL(fileURLWithPath: p))
        }
        let home = (env["HOME"]).map(URL.init(fileURLWithPath:))
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return KeybindingStore(
            url: home.appendingPathComponent(".config/wdm/keybindings.json")
        )
    }

    public func load() throws -> [Keybinding] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Keybinding].self, from: data)
    }

    public func save(_ bindings: [Keybinding]) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bindings)
        try data.write(to: url, options: .atomic)
    }

    public func upsert(_ kb: Keybinding) throws {
        var current = try load()
        current.removeAll { $0.chord == kb.chord }
        current.append(kb)
        current.sort { $0.chord < $1.chord }
        try save(current)
    }

    public func remove(chord: String) throws -> Bool {
        var current = try load()
        let before = current.count
        current.removeAll { $0.chord == chord }
        guard current.count != before else { return false }
        try save(current)
        return true
    }
}
