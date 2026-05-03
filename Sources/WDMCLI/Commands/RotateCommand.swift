public enum RotateCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2, let deg = Int(pos[1]) else {
            throw CLIError.usage("usage: wdm rotate <id> <0|90|180|270> [--no-confirm]")
        }
        guard [0, 90, 180, 270].contains(deg) else {
            throw CLIError.usage("rotation must be 0, 90, 180, or 270")
        }
        let result = try deps.controller.rotate(
            pos[0], degrees: deg,
            confirmer: MutationDispatch.pickConfirmer(deps: deps, args: args)
        )
        return MutationDispatch.mapResult(result, deps: deps)
    }
}
