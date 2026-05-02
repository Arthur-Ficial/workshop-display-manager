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
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(pos[0], in: snap)
        let label = snap.display(id: id)?.name ?? "display \(id)"
        return try MutationDispatch.dispatch(
            deps: deps, args: args,
            description: "Flipped \(label) (\(flip.rawValue))"
        ) {
            try deps.provider.setFlip(displayID: id, flip: flip, options: .noConfirm)
        }
    }
}
