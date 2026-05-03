public enum MirrorCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw CLIError.usage("usage: wdm mirror <src> <dst> [<dst2> ...] [--no-confirm]")
        }
        let result = try deps.controller.mirror(
            source: pos[0], targets: Array(pos.dropFirst()),
            confirmer: MutationDispatch.pickConfirmer(deps: deps, args: args)
        )
        return MutationDispatch.mapResult(result, deps: deps)
    }
}

public enum UnmirrorCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw CLIError.usage("usage: wdm unmirror <id> [--no-confirm]")
        }
        let result = try deps.controller.unmirror(
            alias, confirmer: MutationDispatch.pickConfirmer(deps: deps, args: args)
        )
        return MutationDispatch.mapResult(result, deps: deps)
    }
}
