import WDMCore
import WDMSystem

public enum MoveCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 3, let x = Int(pos[1]), let y = Int(pos[2]) else {
            throw CLIError.usage("usage: wdm move <id> <x> <y> [--no-confirm]")
        }
        return try MutationDispatch.dispatch(
            deps: deps, args: args, alias: pos[0],
            description: { "Moved \($0) to (\(x), \(y))" }
        ) { id in
            try deps.provider.move(displayID: id, to: Point(x: x, y: y), options: .noConfirm)
        }
    }
}
