import WDMSystem

extension WDMController {
    public static let workshopSnapshotName = "last-workshop"

    /// Save the current arrangement under `last-workshop`, then make the
    /// audience display the main display.
    public func workshopStart(audience: String, confirmer: Confirmer) throws -> ApplyResult {
        try mapErrors {
            try profileStore.save(name: Self.workshopSnapshotName, snapshot: provider.snapshot())
            return try main(audience, confirmer: confirmer)
        }
    }

    /// Restore `last-workshop` (no safe-tx; we always honour the saved state).
    public func workshopStop() throws {
        try mapErrors {
            let target = try profileStore.load(name: Self.workshopSnapshotName)
            try ProfileApplier.apply(target: target, using: provider, options: .noConfirm)
        }
    }
}
