import WDMSystem

extension WDMController {
    /// Real-time read of the active arrangement: one entry per online display
    /// with its current origin + rotation. Cheap — single snapshot. Designed
    /// for GUIs polling at ~10 Hz to draw the live layout.
    public func arrangement() throws -> [ArrangementEntry] {
        try mapErrors {
            try provider.snapshot().displays.map {
                ArrangementEntry(
                    id: $0.id, origin: $0.origin, rotationDegrees: $0.rotationDegrees
                )
            }
        }
    }

    /// Apply a bulk arrangement (the GUI's drag-to-rearrange gesture). Every
    /// entry's move runs inside one safe transaction: success → all applied;
    /// failure → previous arrangement restored. Atomicity at the OS level is
    /// best-effort: providers that override `setArrangement` (CGDisplayProvider
    /// will, in a follow-up) batch into one CG transaction; the default impl
    /// applies sequentially and reverts via the snapshot on any failure.
    @discardableResult
    public func setArrangement(_ entries: [ArrangementEntry], confirmer: Confirmer) throws -> ApplyResult {
        try mapErrors {
            let snap = try provider.snapshot()
            for entry in entries where snap.display(id: entry.id) == nil {
                throw WDMError.displayNotFound(entry.id)
            }
            return try safe(confirmer: confirmer, description: "Set arrangement") {
                try provider.setArrangement(entries, options: .noConfirm)
            }
        }
    }
}
