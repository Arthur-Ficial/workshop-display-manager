import WDMSystem

public enum MainCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw CLIError.usage("usage: wdm main <id> [--no-confirm]")
        }
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snap)
        let label = snap.display(id: id)?.name ?? "display \(id)"
        return try MutationDispatch.dispatch(
            deps: deps, args: args,
            description: "Set main to \(label)"
        ) {
            try deps.provider.setMain(displayID: id, options: .noConfirm)
        }
    }
}
