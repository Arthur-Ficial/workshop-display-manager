import WDMSystem

/// Helper that wraps any mutating provider call with the safe-transaction cycle
/// the CLI uses everywhere: snapshot → apply → confirm → revert (if needed).
public enum MutationDispatch {

    public static func dispatch(
        deps: CLIDeps,
        args: [String],
        apply: () throws -> ApplyResult
    ) throws -> Int32 {
        let interactive = !args.contains("--no-confirm")
        let confirmer: Confirmer = interactive ? deps.confirmer : AutoYesConfirmer()
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
