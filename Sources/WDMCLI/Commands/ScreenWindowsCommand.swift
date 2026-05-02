import Foundation
import CoreGraphics
import WDMCore
import WDMSystem

public enum ScreenWindowsCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first, !alias.isEmpty else {
            throw CLIError.usage("usage: wdm screen-windows <id|main> [--json]")
        }
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snap)
        let bounds = CGDisplayBounds(CGDirectDisplayID(id))
        let wins = try deps.windowLister.windows(onDisplay: bounds)
        let useJSON = args.contains("--json")
        if useJSON {
            let data = try JSONEncoder().encode(wins)
            if let s = String(data: data, encoding: .utf8) { deps.stdout.write(s) }
        } else {
            for w in wins {
                deps.stdout.writeLine(
                    "\(w.pid)\t\(w.owner)\t\(w.title)\t\(w.x),\(w.y)\t\(w.width)x\(w.height)"
                )
            }
        }
        return ExitCodes.success
    }
}
