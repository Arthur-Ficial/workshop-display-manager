import WDMCore
import WDMSystem

public enum ModeCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw CLIError.usage("usage: wdm mode <id|main> <WxH@Hz> [--no-confirm]")
        }
        let mode = try Mode.parse(pos[1])
        return try MutationDispatch.dispatch(
            deps: deps, args: args, alias: pos[0],
            description: { "Set \($0) to \(mode.description)" }
        ) { id in
            try deps.provider.setMode(displayID: id, mode: mode, options: .noConfirm)
        }
    }
}
