import WDMCore
import WDMSystem

public enum ListCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let useJSON = args.contains("--json")
        let snapshot = try deps.provider.snapshot()
        let displays = try DisplayAliasOverlay.apply(
            snapshot.displays, provider: deps.provider, env: deps.processEnv
        )
        let resolved = Snapshot(createdAt: snapshot.createdAt, displays: displays)
        if useJSON {
            deps.stdout.write(try JSONFormatter.encode(resolved.displays))
        } else {
            deps.stdout.write(SnapshotTableFormatter.format(resolved))
        }
        return ExitCodes.success
    }
}
