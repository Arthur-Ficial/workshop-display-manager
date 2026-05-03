import WDMCore

public enum MoveCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 3, let x = Int(pos[1]), let y = Int(pos[2]) else {
            throw CLIError.usage("usage: wdm move <id> <x> <y> [--no-confirm]")
        }
        let result = try deps.controller.move(
            pos[0], to: Point(x: x, y: y),
            confirmer: MutationDispatch.pickConfirmer(deps: deps, args: args)
        )
        return MutationDispatch.mapResult(result, deps: deps)
    }
}
