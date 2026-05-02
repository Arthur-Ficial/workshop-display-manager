import WDMSystem

public enum RestoreCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let positional = Args.positional(args)
        guard let name = positional.first else {
            throw CLIError.usage("usage: wdm restore <name>")
        }
        let confirm = !args.contains("--no-confirm")
        let target = try deps.profileStore.load(name: name)
        try ProfileApplier.apply(
            target: target,
            using: deps.provider,
            options: ApplyOptions(confirm: confirm)
        )
        deps.stderr.writeLine("restored profile '\(name)'")
        return ExitCodes.success
    }
}
