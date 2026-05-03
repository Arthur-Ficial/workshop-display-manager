import Foundation

public enum ScreenshotCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw CLIError.usage("usage: wdm screenshot <id|main> --out <path>")
        }
        guard let outPath = Args.flagString(args, name: "--out"), !outPath.isEmpty else {
            throw CLIError.usage("usage: wdm screenshot <id|main> --out <path>")
        }
        let id = try deps.controller.get(alias).id
        let url = URL(fileURLWithPath: outPath)
        try deps.controller.screenshot(alias, to: url, using: deps.screenshotter)
        deps.stderr.writeLine("wdm: captured display \(id) → \(url.path)")
        return ExitCodes.success
    }
}
