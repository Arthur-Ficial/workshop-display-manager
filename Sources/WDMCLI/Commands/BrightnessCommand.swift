public enum BrightnessCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw CLIError.usage("usage: wdm brightness <id|main> [0.0..1.0] [--no-confirm]")
        }

        if pos.count >= 2 {
            guard let value = Float(pos[1]) else {
                throw CLIError.usage("brightness value must be a number 0…1")
            }
            let result = try deps.controller.brightness(
                alias, value: value,
                confirmer: MutationDispatch.pickConfirmer(deps: deps, args: args)
            )
            return MutationDispatch.mapResult(result, deps: deps)
        }

        if let b = try deps.controller.brightness(alias) {
            deps.stdout.writeLine(String(b))
        }
        return ExitCodes.success
    }
}
