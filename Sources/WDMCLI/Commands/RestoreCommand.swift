public enum RestoreCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let positional = Args.positional(args)
        guard let name = positional.first else {
            throw CLIError.usage("usage: wdm restore <name>")
        }
        _ = try deps.controller.restoreProfile(
            name, confirmer: MutationDispatch.pickConfirmer(deps: deps, args: args)
        )
        deps.stderr.writeLine("restored profile '\(name)'")
        return ExitCodes.success
    }
}
