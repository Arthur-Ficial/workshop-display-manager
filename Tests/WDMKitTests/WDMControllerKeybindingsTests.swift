import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController keybindings")
struct WDMControllerKeybindingsTests {
    @Test("upsert + list + remove round-trip through the store")
    func roundTrip() throws {
        let store = makeStore()

        try WDMController.keybindings.upsert(
            Keybinding(chord: "ctrl+1", command: "switch"),
            store: store
        )
        try WDMController.keybindings.upsert(
            Keybinding(chord: "ctrl+2", command: "main 2"),
            store: store
        )

        let listed = try WDMController.keybindings.list(store: store)
        #expect(listed.map(\.chord).sorted() == ["ctrl+1", "ctrl+2"])

        let removed = try WDMController.keybindings.remove(chord: "ctrl+1", store: store)
        #expect(removed == true)
        #expect(try WDMController.keybindings.list(store: store).map(\.chord) == ["ctrl+2"])
    }

    @Test("remove returns false when the chord is not bound")
    func removeMissing() throws {
        let store = makeStore()
        #expect(try WDMController.keybindings.remove(chord: "f13", store: store) == false)
    }

    @Test("installDefaults writes the default set")
    func installDefaults() throws {
        let store = makeStore()
        try WDMController.keybindings.installDefaults(store: store)
        #expect(try WDMController.keybindings.list(store: store).count == Keybinding.defaults.count)
    }

    @Test("normalizeChord rejects malformed tokens with a typed error")
    func normalizeBad() {
        #expect(throws: WDMError.hotkeyChordMalformed("cmd++").self) {
            _ = try WDMController.keybindings.normalize("cmd++")
        }
    }

    @Test("normalizeChord canonicalizes valid tokens")
    func normalizeGood() throws {
        #expect(try WDMController.keybindings.normalize("CMD+SHIFT+1") == "cmd+shift+1")
    }

    private func makeStore() -> KeybindingStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-kb-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return KeybindingStore(url: dir.appendingPathComponent("keybindings.json"))
    }
}
