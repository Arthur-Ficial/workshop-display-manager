import Foundation

public enum FocusCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first, !alias.isEmpty else {
            throw CLIError.usage("usage: wdm focus <id|main>")
        }
        let id = try deps.controller.get(alias).id
        try deps.controller.focus(alias, using: deps.windowMover)
        deps.stderr.writeLine("wdm: focused display \(id)")
        return ExitCodes.success
    }
}
