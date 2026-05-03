import WDMSystem

extension WDMController {
    public enum keybindings {
        public static func list(store: KeybindingStore) throws -> [Keybinding] {
            try store.load()
        }

        public static func upsert(_ keybinding: Keybinding, store: KeybindingStore) throws {
            try store.upsert(keybinding)
        }

        @discardableResult
        public static func remove(chord: String, store: KeybindingStore) throws -> Bool {
            try store.remove(chord: chord)
        }

        public static func installDefaults(store: KeybindingStore) throws {
            try store.save(Keybinding.defaults)
        }

        public static func normalize(_ token: String) throws -> String {
            guard let normalized = Keybinding.normalize(token) else {
                throw WDMError.hotkeyChordMalformed(token)
            }
            return normalized
        }
    }
}
