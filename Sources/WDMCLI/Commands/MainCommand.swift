public enum MainCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw CLIError.usage("usage: wdm main <id> [--no-confirm]")
        }
        let result = try deps.controller.main(
            alias, confirmer: MutationDispatch.pickConfirmer(deps: deps, args: args)
        )
        return MutationDispatch.mapResult(result, deps: deps)
    }
}
