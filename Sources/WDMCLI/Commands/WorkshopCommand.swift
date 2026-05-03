import WDMSystem

public enum WorkshopCommand {
    private static let snapshotName = "last-workshop"

    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let sub = pos.first else {
            throw CLIError.usage("usage: wdm workshop <start|stop> [options]")
        }
        switch sub {
        case "start": return try start(args: args, deps: deps)
        case "stop":  return try stop(args: args, deps: deps)
        default:      throw CLIError.usage("unknown subcommand: \(sub)")
        }
    }

    private static func start(args: [String], deps: CLIDeps) throws -> Int32 {
        guard let audience = parseFlag(args, name: "--audience") else {
            throw CLIError.usage("usage: wdm workshop start --audience <id|main>")
        }
        let snap = try deps.provider.snapshot()
        try deps.profileStore.save(name: snapshotName, snapshot: snap)
        deps.stderr.writeLine("workshop: saved current arrangement to '\(snapshotName)'")

        return try MutationDispatch.dispatch(
            deps: deps, args: args, alias: audience,
            description: { "Workshop mode: main → \($0)" }
        ) { id in
            try deps.provider.setMain(displayID: id, options: .noConfirm)
        }
    }

    private static func stop(args: [String], deps: CLIDeps) throws -> Int32 {
        let target = try deps.profileStore.load(name: snapshotName)
        let confirm = !args.contains("--no-confirm")
        try ProfileApplier.apply(
            target: target, using: deps.provider,
            options: ApplyOptions(confirm: confirm)
        )
        deps.stderr.writeLine("workshop: restored '\(snapshotName)'")
        return ExitCodes.success
    }

    private static func parseFlag(_ args: [String], name: String) -> String? {
        guard let idx = args.firstIndex(of: name), args.count > idx + 1 else { return nil }
        return args[idx + 1]
    }
}
