import WDMSystem
import WDMKit

/// Thin CLI wrapper around `WDMKit.SafeMutation` / `DisplayMutator`. Parses
/// the argv flags (`--no-confirm`, `--confirm`), picks the right confirmer
/// from `CLIDeps`, then delegates the actual snapshot+save-last+safe-tx work
/// to the lib. Maps the lib's `ApplyResult` to a CLI exit code.
public enum MutationDispatch {

    /// Direct dispatch — caller has already resolved the display and built
    /// its own description string. Used by `restore`, `switch`, `cycle`,
    /// `unmirror` and other commands whose description / id-resolution
    /// don't fit the alias→id+label mould.
    public static func dispatch(
        deps: CLIDeps,
        args: [String],
        description: String = "",
        apply: () throws -> ApplyResult
    ) throws -> Int32 {
        let confirmer = pickConfirmer(deps: deps, args: args)
        let result = try SafeMutation.run(
            provider: deps.provider,
            profileStore: deps.profileStore,
            confirmer: confirmer,
            description: description,
            apply: apply
        )
        return mapResult(result, deps: deps)
    }

    /// Alias dispatch — the common case. Resolves the user-facing alias
    /// (e.g. "main", "1") to a `CGDirectDisplayID` and passes both the id
    /// and the resolved display name into the closures so each command no
    /// longer has to repeat `snapshot + DisplayResolver.resolve + label`.
    public static func dispatch(
        deps: CLIDeps,
        args: [String],
        alias: String,
        description: (String) -> String,
        apply: (UInt32) throws -> ApplyResult
    ) throws -> Int32 {
        let confirmer = pickConfirmer(deps: deps, args: args)
        let result = try DisplayMutator.dispatch(
            provider: deps.provider,
            profileStore: deps.profileStore,
            confirmer: confirmer,
            alias: alias,
            description: description,
            apply: apply
        )
        return mapResult(result, deps: deps)
    }

    private static func pickConfirmer(deps: CLIDeps, args: [String]) -> Confirmer {
        let interactive = !args.contains("--no-confirm")
        let useNative = args.contains("--confirm")
        if !interactive { return AutoYesConfirmer() }
        if useNative   { return deps.nativeConfirmer }
        return deps.confirmer
    }

    private static func mapResult(_ result: ApplyResult, deps: CLIDeps) -> Int32 {
        switch result {
        case .applied:    return ExitCodes.success
        case .noChange:   return ExitCodes.success
        case .reverted:
            deps.stderr.writeLine("change reverted")
            return ExitCodes.cancelled
        }
    }
}
