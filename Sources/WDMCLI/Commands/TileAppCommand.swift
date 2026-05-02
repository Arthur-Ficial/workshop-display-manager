import Foundation
import WDMCore
import WDMSystem

public enum TileAppCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let pattern = pos.first, !pattern.isEmpty else {
            throw CLIError.usage("usage: wdm tile-app <pattern> --across <id1,id2,...>")
        }
        guard let csv = parseFlagString(args, name: "--across"), !csv.isEmpty else {
            throw CLIError.usage("usage: wdm tile-app <pattern> --across <id1,id2,...>")
        }
        let snap = try deps.provider.snapshot()
        let displayIDs = try csv
            .split(separator: ",")
            .map { try DisplayResolver.resolve(String($0), in: snap) }
        try deps.windowMover.tileAcross(pattern: pattern, displayIDs: displayIDs)
        let csvIDs = displayIDs.map(String.init).joined(separator: ",")
        deps.stderr.writeLine("wdm: tiled '\(pattern)' across \(csvIDs)")
        return ExitCodes.success
    }

    private static func parseFlagString(_ args: [String], name: String) -> String? {
        guard let i = args.firstIndex(of: name), args.count > i + 1 else { return nil }
        return args[i + 1]
    }
}
