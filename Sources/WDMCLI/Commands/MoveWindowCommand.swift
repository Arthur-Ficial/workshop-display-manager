import Foundation
import WDMCore
import WDMSystem

public enum MoveWindowCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let pattern = pos.first, !pattern.isEmpty else {
            throw CLIError.usage("usage: wdm move-window <app|pattern> --to <id|main>")
        }
        guard let dstToken = parseFlagString(args, name: "--to"), !dstToken.isEmpty else {
            throw CLIError.usage("usage: wdm move-window <app|pattern> --to <id|main>")
        }
        let snap = try deps.provider.snapshot()
        let dstID = try DisplayResolver.resolve(dstToken, in: snap)
        try deps.windowMover.move(pattern: pattern, displayID: dstID)
        deps.stderr.writeLine("wdm: moved windows matching '\(pattern)' → display \(dstID)")
        return ExitCodes.success
    }

    private static func parseFlagString(_ args: [String], name: String) -> String? {
        guard let i = args.firstIndex(of: name), args.count > i + 1 else { return nil }
        return args[i + 1]
    }
}
