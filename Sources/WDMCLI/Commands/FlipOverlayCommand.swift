import Foundation
import WDMCore

public enum FlipOverlayCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2, let flip = Flip.parse(pos[1]) else {
            throw CLIError.usage(
                "usage: wdm flip-overlay <id> <none|horizontal|vertical|both|h|v|hv|off> [--duration-ms N]"
            )
        }
        let durationMs = Args.flagInt(args, name: "--duration-ms")

        try deps.controller.flipOverlay(
            pos[0], flip: flip, durationMs: durationMs, using: deps.overlayFlipper
        )
        return ExitCodes.success
    }
}
