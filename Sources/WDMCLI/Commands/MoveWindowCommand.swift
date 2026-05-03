import Foundation

public enum MoveWindowCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let pattern = pos.first, !pattern.isEmpty else {
            throw CLIError.usage("usage: wdm move-window <app|pattern> --to <id|main>")
        }
        guard let dstToken = Args.flagString(args, name: "--to"), !dstToken.isEmpty else {
            throw CLIError.usage("usage: wdm move-window <app|pattern> --to <id|main>")
        }
        let dstID = try deps.controller.get(dstToken).id
        try deps.controller.moveWindow(pattern: pattern, to: dstToken, using: deps.windowMover)
        deps.stderr.writeLine("wdm: moved windows matching '\(pattern)' → display \(dstID)")
        return ExitCodes.success
    }
}
