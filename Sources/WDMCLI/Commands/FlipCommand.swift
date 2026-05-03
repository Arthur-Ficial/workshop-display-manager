import WDMCore
import WDMSystem

public enum FlipCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2, let flip = Flip.parse(pos[1]) else {
            throw CLIError.usage(
                "usage: wdm flip <id> <none|horizontal|vertical|both|h|v|hv|off> [--no-confirm]"
            )
        }
        return try MutationDispatch.dispatch(
            deps: deps, args: args, alias: pos[0],
            description: { "Flipped \($0) (\(flip.rawValue))" }
        ) { id in
            try deps.provider.setFlip(displayID: id, flip: flip, options: .noConfirm)
        }
    }
}
