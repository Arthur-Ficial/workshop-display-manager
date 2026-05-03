import WDMKit

public enum PipCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let srcToken = pos.first else {
            throw WDMError.usage(
                "usage: wdm pip <src> [--on <dst>] [--size WxH] [--flip <axis>] [--duration-ms N]"
            )
        }
        let plan = try buildPlan(srcToken: srcToken, args: args)
        try deps.controller.pip(plan: plan, using: deps.pipFlipper)
        return ExitCodes.success
    }

    private static func buildPlan(srcToken: String, args: [String]) throws -> WDMController.PipPlan {
        let size = try parseSize(args)
        let flip = try parseFlip(args)
        let position = parsePosition(args)
        return WDMController.PipPlan(
            sourceAlias: srcToken,
            destinationAlias: Args.flagString(args, name: "--on"),
            size: size,
            position: position,
            flip: flip,
            durationMs: Args.flagInt(args, name: "--duration-ms"),
            remoteControl: args.contains("--remote")
        )
    }

    private static func parseSize(_ args: [String]) throws -> PipSize {
        guard let token = Args.flagString(args, name: "--size") else { return .defaultSize }
        guard let parsed = PipSize.parse(token) else {
            throw WDMError.usage("pip: --size must be WxH (e.g. 1280x720), got '\(token)'")
        }
        return parsed
    }

    private static func parseFlip(_ args: [String]) throws -> Flip {
        guard let token = Args.flagString(args, name: "--flip") else { return .none }
        guard let parsed = Flip.parse(token) else {
            throw WDMError.usage(
                "pip: --flip must be one of none|horizontal|vertical|both|h|v|hv|off, got '\(token)'"
            )
        }
        return parsed
    }

    private static func parsePosition(_ args: [String]) -> PipPosition? {
        guard let xs = Args.flagString(args, name: "--x"),
              let ys = Args.flagString(args, name: "--y"),
              let xi = Int(xs), let yi = Int(ys) else { return nil }
        return PipPosition(x: xi, y: yi)
    }
}
