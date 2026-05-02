import Foundation
import WDMCore
import WDMSystem

public enum PipCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let srcToken = pos.first else {
            throw CLIError.usage(
                "usage: wdm pip <src> [--on <dst>] [--size WxH] [--flip <axis>] [--duration-ms N]"
            )
        }
        let snap = try deps.provider.snapshot()
        let srcID = try DisplayResolver.resolve(srcToken, in: snap)
        let dstID: UInt32
        if let dstToken = parseFlagString(args, name: "--on") {
            dstID = try DisplayResolver.resolve(dstToken, in: snap)
        } else {
            guard let main = snap.main?.id else {
                throw CLIError.usage("pip: no main display found and no --on specified")
            }
            dstID = main
        }
        let size: PipSize
        if let token = parseFlagString(args, name: "--size") {
            guard let parsed = PipSize.parse(token) else {
                throw CLIError.usage("pip: --size must be WxH (e.g. 1280x720), got '\(token)'")
            }
            size = parsed
        } else {
            size = .defaultSize
        }
        let flip: Flip
        if let token = parseFlagString(args, name: "--flip") {
            guard let parsed = Flip.parse(token) else {
                throw CLIError.usage("pip: --flip must be one of none|horizontal|vertical|both|h|v|hv|off, got '\(token)'")
            }
            flip = parsed
        } else {
            flip = .none
        }
        let durationMs = parseFlagInt(args, name: "--duration-ms")
        let position: PipPosition?
        if let xs = parseFlagString(args, name: "--x"),
           let ys = parseFlagString(args, name: "--y"),
           let xi = Int(xs), let yi = Int(ys) {
            position = PipPosition(x: xi, y: yi)
        } else {
            position = nil
        }

        try deps.pipFlipper.run(
            sourceID: srcID, destinationID: dstID,
            size: size, position: position, flip: flip, durationMs: durationMs
        )
        return ExitCodes.success
    }

    private static func parseFlagString(_ args: [String], name: String) -> String? {
        guard let i = args.firstIndex(of: name), args.count > i + 1 else { return nil }
        return args[i + 1]
    }

    private static func parseFlagInt(_ args: [String], name: String) -> Int? {
        parseFlagString(args, name: name).flatMap(Int.init)
    }
}
