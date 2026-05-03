import WDMSystem

public enum MainCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw CLIError.usage("usage: wdm main <id> [--no-confirm]")
        }
        return try MutationDispatch.dispatch(
            deps: deps, args: args, alias: alias,
            description: { "Set main to \($0)" }
        ) { id in
            try deps.provider.setMain(displayID: id, options: .noConfirm)
        }
    }
}
