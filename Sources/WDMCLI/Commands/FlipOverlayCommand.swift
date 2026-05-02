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
        let durationMs = parseFlagInt(args, name: "--duration-ms")

        try deps.overlayFlipper.run(displayID: id, flip: flip, durationMs: durationMs)
        return ExitCodes.success
    }

    private static func parseFlagInt(_ args: [String], name: String) -> Int? {
        guard let i = args.firstIndex(of: name), args.count > i + 1 else { return nil }
        return Int(args[i + 1])
    }
}
