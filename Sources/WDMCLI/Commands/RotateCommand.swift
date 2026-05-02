import WDMSystem

public enum RotateCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2, let deg = Int(pos[1]) else {
            throw CLIError.usage("usage: wdm rotate <id> <0|90|180|270> [--no-confirm]")
        }
        guard [0, 90, 180, 270].contains(deg) else {
            throw CLIError.usage("rotation must be 0, 90, 180, or 270")
        }
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(pos[0], in: snap)
        let label = snap.display(id: id)?.name ?? "display \(id)"
        return try MutationDispatch.dispatch(
            deps: deps, args: args,
            description: "Rotated \(label) to \(deg)°"
        ) {
            try deps.provider.rotate(displayID: id, degrees: deg, options: .noConfirm)
        }
    }
}
