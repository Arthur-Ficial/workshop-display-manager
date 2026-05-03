import Foundation
import WDMKit

/// Capture every active display to `<dir>/display-<id>.png`.
public enum ShotAllCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        guard let dirPath = Args.flagString(args, name: "--dir"), !dirPath.isEmpty else {
            throw WDMError.usage("usage: wdm shot-all --dir <path>")
        }
        let dirURL = URL(fileURLWithPath: dirPath)
        let paths = try deps.controller.shotAll(to: dirURL, using: deps.screenshotter)
        for url in paths { deps.stdout.writeLine(url.path) }
        deps.stderr.writeLine("wdm: captured \(paths.count) displays into \(dirURL.path)")
        return ExitCodes.success
    }
}
