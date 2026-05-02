import WDMSystem

/// Helper that wraps any mutating provider call with the safe-transaction cycle
/// the CLI uses everywhere: snapshot → apply → confirm → revert (if needed).
public enum MutationDispatch {

    public static func dispatch(
        deps: CLIDeps,
        args: [String],
        apply: () throws -> ApplyResult
    ) throws -> Int32 {
        // Crash recovery: persist current state to profile 'last' before any mutation.
        // If the process is killed mid-mutation, the user can `wdm restore last`.
        let preState = try deps.provider.snapshot()
        try? deps.profileStore.save(name: "last", snapshot: preState)

        let interactive = !args.contains("--no-confirm")
        let useNative = args.contains("--confirm")
        let confirmer: Confirmer
        if !interactive {
            confirmer = AutoYesConfirmer()
        } else if useNative {
            confirmer = deps.nativeConfirmer
        } else {
            confirmer = deps.confirmer
        }
        let result = try SafeTransaction.run(
            provider: deps.provider,
            confirmer: confirmer,
            timeoutSeconds: 15,
            apply: apply
        )
        switch result {
        case .applied:    return ExitCodes.success
        case .noChange:   return ExitCodes.success
        case .reverted:
            deps.stderr.writeLine("change reverted")
            return ExitCodes.cancelled
        }
    }
}
