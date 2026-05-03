import WDMKit

public enum WorkshopCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let sub = pos.first else {
            throw WDMError.usage("usage: wdm workshop <start|stop> [options]")
        }
        switch sub {
        case "start": return try start(args: args, deps: deps)
        case "stop":  return try stop(args: args, deps: deps)
        default:      throw WDMError.usage("unknown subcommand: \(sub)")
        }
    }

    private static func start(args: [String], deps: CLIDeps) throws -> Int32 {
        guard let audience = parseFlag(args, name: "--audience") else {
            throw WDMError.usage("usage: wdm workshop start --audience <id|main>")
        }
        let confirmer = MutationDispatch.pickConfirmer(deps: deps, args: args)
        deps.stderr.writeLine("workshop: saved current arrangement to '\(WDMController.workshopSnapshotName)'")
        let result = try deps.controller.workshopStart(audience: audience, confirmer: confirmer)
        return MutationDispatch.mapResult(result, deps: deps)
    }

    private static func stop(args: [String], deps: CLIDeps) throws -> Int32 {
        try deps.controller.workshopStop()
        deps.stderr.writeLine("workshop: restored '\(WDMController.workshopSnapshotName)'")
        return ExitCodes.success
    }

    private static func parseFlag(_ args: [String], name: String) -> String? {
        guard let idx = args.firstIndex(of: name), args.count > idx + 1 else { return nil }
        return args[idx + 1]
    }
}
