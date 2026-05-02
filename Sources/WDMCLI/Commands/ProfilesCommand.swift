public enum ProfilesCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let useJSON = args.contains("--json")
        let names = deps.profileStore.list()
        if useJSON {
            deps.stdout.write(try JSONFormatter.encode(names))
        } else {
            for n in names { deps.stdout.writeLine(n) }
        }
        return ExitCodes.success
    }
}
