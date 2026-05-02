import WDMSystem

public enum ListCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let useJSON = args.contains("--json")
        let snapshot = try deps.provider.snapshot()
        if useJSON {
            deps.stdout.write(try JSONFormatter.encode(snapshot.displays))
        } else {
            deps.stdout.write(SnapshotTableFormatter.format(snapshot))
        }
        return ExitCodes.success
    }
}
