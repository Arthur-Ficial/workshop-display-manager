public enum SaveCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let positional = Args.positional(args)
        guard let name = positional.first else {
            throw CLIError.usage("usage: wdm save <name>")
        }
        let snap = try deps.provider.snapshot()
        try deps.profileStore.save(name: name, snapshot: snap)
        deps.stderr.writeLine("saved profile '\(name)'")
        return ExitCodes.success
    }
}
