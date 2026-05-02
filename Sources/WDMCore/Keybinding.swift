import Foundation

/// One key-chord → wdm command mapping. The chord is a normalized
/// `+`-separated string: `cmd+shift+1`, `ctrl+opt+f`, `cmd+shift+arrow-left`.
/// The command is the wdm verb + args to run when the chord fires —
/// e.g. `switch`, `cycle`, `flip-overlay 2 vertical`.
public struct Keybinding: Sendable, Codable, Equatable, Hashable {
    public let chord: String
    public let command: String
    public let enabled: Bool

    public init(chord: String, command: String, enabled: Bool = true) {
        self.chord = chord
        self.command = command
        self.enabled = enabled
    }

    /// Default keybinding set. Choices avoid conflicts with macOS / common
    /// editor shortcuts (cmd+ctrl+shift is a niche prefix, none of these
    /// triples are bound by the OS or major apps as of macOS 26.x).
    public static let defaults: [Keybinding] = [
        Keybinding(chord: "cmd+ctrl+shift+s", command: "switch"),
        Keybinding(chord: "cmd+ctrl+shift+c", command: "cycle"),
        Keybinding(chord: "cmd+ctrl+shift+l", command: "list"),
        Keybinding(chord: "cmd+ctrl+shift+r", command: "restore last"),
        Keybinding(chord: "cmd+ctrl+shift+z", command: "sleep"),
    ]

    /// Normalize a user-typed chord: lowercase, sort modifiers in canonical
    /// order (cmd, ctrl, opt, shift, fn), single-key suffix preserved.
    /// Rejects empty / single-modifier-only chords.
    public static func normalize(_ raw: String) -> String? {
        let parts = raw.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else { return nil }
        let modifiers = Set(["cmd", "command", "ctrl", "control", "opt", "option", "alt", "shift", "fn"])
        let canonical = ["cmd", "ctrl", "opt", "shift", "fn"]
        let alias: [String: String] = [
            "command": "cmd", "control": "ctrl", "option": "opt", "alt": "opt",
        ]
        var mods: Set<String> = []
        var keys: [String] = []
        for p in parts {
            let resolved = alias[p] ?? p
            if modifiers.contains(p) || modifiers.contains(resolved) {
                mods.insert(resolved)
            } else {
                keys.append(resolved)
            }
        }
        guard keys.count == 1, !keys[0].isEmpty else { return nil }
        let sortedMods = canonical.filter { mods.contains($0) }
        return (sortedMods + keys).joined(separator: "+")
    }
}
