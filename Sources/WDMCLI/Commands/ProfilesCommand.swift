public enum ProfilesCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        if pos.first == "remove" {
            return try remove(args: args, deps: deps)
        }
        let useJSON = args.contains("--json")
        let names = try deps.profileStore.list()
        if useJSON {
            deps.stdout.write(try JSONFormatter.encode(names))
        } else {
            for n in names { deps.stdout.writeLine(n) }
        }
        return ExitCodes.success
    }

    private static func remove(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw CLIError.usage("usage: wdm profiles remove <name>")
        }
        let name = pos[1]
        try deps.profileStore.remove(name: name)
        deps.stderr.writeLine("removed: \(name)")
        return ExitCodes.success
    }
}
