import Foundation

public enum TileAppCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let pattern = pos.first, !pattern.isEmpty else {
            throw CLIError.usage("usage: wdm tile-app <pattern> --across <id1,id2,...>")
        }
        guard let csv = Args.flagString(args, name: "--across"), !csv.isEmpty else {
            throw CLIError.usage("usage: wdm tile-app <pattern> --across <id1,id2,...>")
        }
        let aliases = csv.split(separator: ",").map(String.init)
        let displayIDs = try aliases.map { try deps.controller.get($0).id }
        try deps.controller.tileApp(pattern: pattern, across: aliases, using: deps.windowMover)
        let csvIDs = displayIDs.map(String.init).joined(separator: ",")
        deps.stderr.writeLine("wdm: tiled '\(pattern)' across \(csvIDs)")
        return ExitCodes.success
    }
}
