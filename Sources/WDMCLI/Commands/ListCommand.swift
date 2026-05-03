import WDMCore

public enum ListCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let useJSON = args.contains("--json")
        let resolved = try deps.controller.snapshot()
        if useJSON {
            deps.stdout.write(try JSONFormatter.encode(resolved.displays))
        } else {
            deps.stdout.write(SnapshotTableFormatter.format(resolved))
        }
        return ExitCodes.success
    }
}
