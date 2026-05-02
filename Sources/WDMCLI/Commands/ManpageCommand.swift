public enum ManpageCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        deps.stdout.write(ManpageFormatter.render())
        return ExitCodes.success
    }
}
