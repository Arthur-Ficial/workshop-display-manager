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
        if let dstToken = Args.flagString(args, name: "--on") {
            dstID = try DisplayResolver.resolve(dstToken, in: snap)
        } else {
            guard let main = snap.main?.id else {
                throw CLIError.usage("pip: no main display found and no --on specified")
            }
            dstID = main
        }
        let size: PipSize
        if let token = Args.flagString(args, name: "--size") {
            guard let parsed = PipSize.parse(token) else {
                throw CLIError.usage("pip: --size must be WxH (e.g. 1280x720), got '\(token)'")
            }
            size = parsed
        } else {
            size = .defaultSize
        }
        let flip: Flip
        if let token = Args.flagString(args, name: "--flip") {
            guard let parsed = Flip.parse(token) else {
                throw CLIError.usage("pip: --flip must be one of none|horizontal|vertical|both|h|v|hv|off, got '\(token)'")
            }
            flip = parsed
        } else {
            flip = .none
        }
        let durationMs = Args.flagInt(args, name: "--duration-ms")
        let position: PipPosition?
        if let xs = Args.flagString(args, name: "--x"),
           let ys = Args.flagString(args, name: "--y"),
           let xi = Int(xs), let yi = Int(ys) {
            position = PipPosition(x: xi, y: yi)
        } else {
            position = nil
        }
        let remote = args.contains("--remote")

        try deps.pipFlipper.run(
            sourceID: srcID, destinationID: dstID,
            size: size, position: position, flip: flip, durationMs: durationMs,
            remoteControl: remote
        )
        return ExitCodes.success
    }
}
