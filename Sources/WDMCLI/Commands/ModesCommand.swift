public enum ModesCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let useJSON = args.contains("--json")
        let positional = Args.positional(args)
        guard let alias = positional.first else {
            throw CLIError.usage("usage: wdm modes <id|main>")
        }
        let modes = try deps.controller.modes(alias)
        let strings = modes.map { $0.description }
        if useJSON {
            deps.stdout.write(try JSONFormatter.encode(strings))
        } else {
            for s in strings { deps.stdout.writeLine(s) }
        }
        return ExitCodes.success
    }
}
