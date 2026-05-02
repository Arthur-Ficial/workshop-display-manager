import Foundation
import WDMCore
import WDMSystem

public enum ScreenshotCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw CLIError.usage("usage: wdm screenshot <id|main> --out <path>")
        }
        guard let outPath = Args.flagString(args, name: "--out"), !outPath.isEmpty else {
            throw CLIError.usage("usage: wdm screenshot <id|main> --out <path>")
        }
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snap)
        let url = URL(fileURLWithPath: outPath)
        try deps.screenshotter.capture(displayID: id, to: url)
        deps.stderr.writeLine("wdm: captured display \(id) → \(url.path)")
        return ExitCodes.success
    }
}
