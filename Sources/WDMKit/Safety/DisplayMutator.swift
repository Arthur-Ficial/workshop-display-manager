import WDMCore
import WDMSystem

/// Reusable alias-based mutation primitive: resolve `alias` to a display ID,
/// build a human-readable description from the resolved name, and run the
/// supplied apply closure inside a `SafeMutation` cycle. Frontends (CLI, GUI,
/// web, …) all build on this — they only differ in how they construct the
/// `Confirmer` and what they do with the returned `ApplyResult`.
public enum DisplayMutator {
    public static func dispatch(
        provider: DisplayProvider,
        profileStore: ProfileStore,
        confirmer: Confirmer,
        alias: String,
        description: (String) -> String,
        timeoutSeconds: Int = 15,
        apply: (UInt32) throws -> ApplyResult
    ) throws -> ApplyResult {
        let snap = try provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snap)
        let label = snap.display(id: id)?.name ?? "display \(id)"
        return try SafeMutation.run(
            provider: provider,
            profileStore: profileStore,
            confirmer: confirmer,
            description: description(label),
            timeoutSeconds: timeoutSeconds
        ) {
            try apply(id)
        }
    }
}
