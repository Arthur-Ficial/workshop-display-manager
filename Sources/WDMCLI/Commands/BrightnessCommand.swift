import WDMSystem

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
            return try MutationDispatch.dispatch(
                deps: deps, args: args, alias: alias,
                description: { "Set \($0) brightness to \(Int((value * 100).rounded()))%" }
            ) { id in
                try deps.provider.setBrightness(displayID: id, value: value, options: .noConfirm)
            }
        }

        // Read mode.
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snap)
        if let b = try deps.provider.brightness(for: id) {
            deps.stdout.writeLine(String(b))
        }
        return ExitCodes.success
    }
}
