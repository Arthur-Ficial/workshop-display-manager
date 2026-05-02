import Foundation
import WDMCore
import WDMSystem

/// Capture every active display to `<dir>/display-<id>.png` in one shot.
/// Single-purpose helper that loops `wdm screenshot` over `provider.snapshot()`,
/// useful for "what is every screen showing right now?" verification when
/// debugging multi-monitor or virtual-display setups.
public enum ShotAllCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        guard let dirPath = Args.flagString(args, name: "--dir"), !dirPath.isEmpty else {
            throw CLIError.usage("usage: wdm shot-all --dir <path>")
        }
        let dirURL = URL(fileURLWithPath: dirPath)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let snap = try deps.provider.snapshot()
        for display in snap.displays {
            let out = dirURL.appendingPathComponent("display-\(display.id).png")
            try deps.screenshotter.capture(displayID: display.id, to: out)
            deps.stdout.writeLine(out.path)
        }
        deps.stderr.writeLine("wdm: captured \(snap.displays.count) displays into \(dirURL.path)")
        return ExitCodes.success
    }
}
