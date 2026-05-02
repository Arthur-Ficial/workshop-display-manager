public enum SaveCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        if args.contains("--auto") {
            let snap = try deps.provider.snapshot()
            let auto = AutoProfileStore.resolve(from: deps.profileStore)
            try auto.save(snap)
            deps.stderr.writeLine("saved auto profile (\(snap.displays.count) displays)")
            return ExitCodes.success
        }
        let positional = Args.positional(args)
        guard let name = positional.first else {
            throw CLIError.usage("usage: wdm save <name> | wdm save --auto")
        }
        let snap = try deps.provider.snapshot()
        try deps.profileStore.save(name: name, snapshot: snap)
        deps.stderr.writeLine("saved profile '\(name)'")
        return ExitCodes.success
    }
}
