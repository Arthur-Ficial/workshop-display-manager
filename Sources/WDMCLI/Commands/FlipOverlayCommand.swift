import Foundation
import WDMCore
import WDMSystem

public enum FlipOverlayCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2, let flip = Flip.parse(pos[1]) else {
            throw CLIError.usage(
                "usage: wdm flip-overlay <id> <none|horizontal|vertical|both|h|v|hv|off> [--duration-ms N]"
            )
        }
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(pos[0], in: snap)
        let durationMs = Args.flagInt(args, name: "--duration-ms")

        try deps.overlayFlipper.run(displayID: id, flip: flip, durationMs: durationMs)
        return ExitCodes.success
    }
}
