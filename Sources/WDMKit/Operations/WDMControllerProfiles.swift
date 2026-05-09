import WDMSystem

extension WDMController {
    public func saveProfile(_ name: String) throws {
        try mapErrors {
            try profileStore.save(name: name, snapshot: provider.snapshot())
        }
    }

    public func saveAutoProfile() throws -> Int {
        try mapErrors {
            let snap = try provider.snapshot()
            let auto = AutoProfileStore.resolve(from: profileStore)
            try auto.save(snap)
            return snap.displays.count
        }
    }

    public func profiles() throws -> [String] {
        try mapErrors {
            try profileStore.list()
        }
    }

    public func removeProfile(_ name: String) throws {
        try mapErrors {
            try profileStore.remove(name: name)
        }
    }

    public func restoreProfile(_ name: String, confirmer: Confirmer) throws -> ApplyResult {
        try mapErrors {
            let target = try profileStore.load(name: name)
            let current = try provider.snapshot()
            return try safe(confirmer: confirmer, description: "Restore profile \(name)") {
                try ProfileApplier.apply(target: target, using: provider, options: .noConfirm)
                return current == target ? .noChange : .applied
            }
        }
    }
}
