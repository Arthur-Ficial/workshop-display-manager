import WDMCore
import WDMSystem

public enum ModeCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw CLIError.usage("usage: wdm mode <id|main> <WxH@Hz> [--no-confirm]")
        }
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(pos[0], in: snap)
        let mode = try Mode.parse(pos[1])
        let label = snap.display(id: id)?.name ?? "display \(id)"
        return try MutationDispatch.dispatch(
            deps: deps, args: args,
            description: "Set \(label) to \(mode.description)"
        ) {
            try deps.provider.setMode(displayID: id, mode: mode, options: .noConfirm)
        }
    }
}
