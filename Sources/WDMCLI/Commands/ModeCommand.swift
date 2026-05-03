import WDMCore

public enum ModeCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw CLIError.usage("usage: wdm mode <id|main> <WxH@Hz> [--no-confirm]")
        }
        let mode = try Mode.parse(pos[1])
        let result = try deps.controller.mode(
            pos[0], mode: mode,
            confirmer: MutationDispatch.pickConfirmer(deps: deps, args: args)
        )
        return MutationDispatch.mapResult(result, deps: deps)
    }
}
