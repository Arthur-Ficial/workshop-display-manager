import WDMCore
import WDMSystem

/// Reusable mutation primitive: snapshot the current configuration, persist
/// it as the crash-recovery profile (`last`), then run the apply closure
/// inside a `SafeTransaction` with the supplied confirmer.
///
/// Frontends (CLI, GUI, web, …) all want the same flow around any change to
/// the display configuration. This is that flow with no argv coupling, no
/// stdout writing, no exit codes — pure data in, `ApplyResult` out.
public enum SafeMutation {
    public static func run(
        provider: DisplayProvider,
        profileStore: ProfileStore,
        confirmer: Confirmer,
        description: String = "",
        timeoutSeconds: Int = 15,
        apply: () throws -> ApplyResult
    ) throws -> ApplyResult {
        let preState = try provider.snapshot()
        do {
            try profileStore.save(name: "last", snapshot: preState)
        } catch {
            throw CLIError.ioError(
                "could not save crash-recovery profile 'last': \(error)"
            )
        }
        return try SafeTransaction.run(
            provider: provider,
            confirmer: confirmer,
            message: description,
            timeoutSeconds: timeoutSeconds,
            apply: apply
        )
    }
}
