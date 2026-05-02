import Foundation
import WDMCore
import WDMSystem

public enum FocusCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first, !alias.isEmpty else {
            throw CLIError.usage("usage: wdm focus <id|main>")
        }
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snap)
        try deps.windowMover.focus(displayID: id)
        deps.stderr.writeLine("wdm: focused display \(id)")
        return ExitCodes.success
    }
}
