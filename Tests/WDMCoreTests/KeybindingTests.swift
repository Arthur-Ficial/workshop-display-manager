import Testing
import Foundation
@testable import WDMCore

@Suite("Keybinding")
struct KeybindingTests {

    @Test("normalize sorts modifiers canonically")
    func normalizeSort() {
        #expect(Keybinding.normalize("shift+cmd+s") == "cmd+shift+s")
        #expect(Keybinding.normalize("opt+ctrl+1") == "ctrl+opt+1")
        #expect(Keybinding.normalize("fn+shift+a") == "shift+fn+a")
    }

    @Test("normalize accepts modifier aliases")
    func aliases() {
        #expect(Keybinding.normalize("command+shift+s") == "cmd+shift+s")
        #expect(Keybinding.normalize("control+option+1") == "ctrl+opt+1")
        #expect(Keybinding.normalize("alt+shift+a") == "opt+shift+a")
    }

    @Test("normalize lowercases the suffix key")
    func lowercase() {
        #expect(Keybinding.normalize("Cmd+Shift+S") == "cmd+shift+s")
    }

    @Test("normalize rejects malformed input")
    func reject() {
        #expect(Keybinding.normalize("") == nil)
        #expect(Keybinding.normalize("cmd") == nil)         // modifier only
        #expect(Keybinding.normalize("a") == nil)           // no modifier
        #expect(Keybinding.normalize("cmd+a+b") == nil)     // two non-modifier keys
    }

    @Test("default set has 5 entries with no duplicate chords")
    func defaults() {
        let chords = Keybinding.defaults.map(\.chord)
        #expect(Keybinding.defaults.count == 5)
        #expect(Set(chords).count == chords.count)
    }

    @Test("Codable round-trip")
    func codable() throws {
        let kb = Keybinding(chord: "cmd+shift+s", command: "switch", enabled: true)
        let data = try JSONEncoder().encode(kb)
        let decoded = try JSONDecoder().decode(Keybinding.self, from: data)
        #expect(decoded == kb)
    }
}
