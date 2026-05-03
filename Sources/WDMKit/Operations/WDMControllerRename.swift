import WDMSystem

extension WDMController {
    public struct RenameOutcome: Equatable, Sendable {
        public let displayID: UInt32
        public let name: String
        public let key: String
    }

    public func rename(_ alias: String, to name: String, store: DisplayAliasStore) throws -> RenameOutcome {
        try mapErrors {
            let id = try resolve(alias)
            let edidStableID = (try? provider.edid(for: id))?.stableID
            let key = DisplayAliasStore.key(forID: id, edidStableID: edidStableID)
            try store.upsert(key: key, name: name)
            return RenameOutcome(displayID: id, name: name, key: key)
        }
    }

    @discardableResult
    public func removeRename(_ alias: String, store: DisplayAliasStore) throws -> Bool {
        try mapErrors {
            let id = try resolve(alias)
            let edidStableID = (try? provider.edid(for: id))?.stableID
            let key = DisplayAliasStore.key(forID: id, edidStableID: edidStableID)
            return try store.remove(key: key)
        }
    }
}
