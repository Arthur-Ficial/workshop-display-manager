import WDMCore

public enum FlipCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2, let flip = Flip.parse(pos[1]) else {
            throw CLIError.usage(
                "usage: wdm flip <id> <none|horizontal|vertical|both|h|v|hv|off> [--no-confirm]"
            )
        }
        let result = try deps.controller.flip(
            pos[0], flip: flip,
            confirmer: MutationDispatch.pickConfirmer(deps: deps, args: args)
        )
        return MutationDispatch.mapResult(result, deps: deps)
    }
}
