import WDMCore

/// `wdm scale <id> <WxH> [--no-confirm]`  — change a display's logical
/// resolution by name. Convenience verb on top of `wdm mode` that drops
/// the `@Hz` requirement and lets you say `looks-like 2560x1440` instead
/// of memorising every refresh rate. Picks the highest refresh rate
/// available for the requested logical size.
///
/// `wdm scale <id> list` prints every distinct logical resolution this
/// display can drive — same data as `wdm modes`, deduped to one line per
/// (W,H) pair so users see scaling options at a glance.
public enum ScaleCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw CLIError.usage(
                "usage: wdm scale <id|main> <WxH>\n" +
                "       wdm scale <id|main> looks-like <WxH>\n" +
                "       wdm scale <id|main> list"
            )
        }
        switch pos[1] {
        case "list":
            return try list(options: deps.controller.scaleOptions(pos[0]), deps: deps)
        case "looks-like":
            guard pos.count >= 3 else {
                throw CLIError.usage("usage: wdm scale <id> looks-like <WxH>")
            }
            return try apply(target: pos[2], alias: pos[0], args: args, deps: deps)
        default:
            return try apply(target: pos[1], alias: pos[0], args: args, deps: deps)
        }
    }

    private static func list(
        options: [WDMScaleOption], deps: CLIDeps
    ) throws -> Int32 {
        for option in options {
            deps.stdout.writeLine("\(option.label)\t\(option.isCurrent ? "*" : " ")")
        }
        return ExitCodes.success
    }

    private static func apply(
        target: String, alias: String, args: [String], deps: CLIDeps
    ) throws -> Int32 {
        let size = try parseSize(target)
        let result = try deps.controller.scale(
            alias, width: size.0, height: size.1,
            confirmer: MutationDispatch.pickConfirmer(deps: deps, args: args)
        )
        return MutationDispatch.mapResult(result, deps: deps)
    }

    private static func parseSize(_ target: String) throws -> (Int, Int) {
        let parts = target.lowercased().split(separator: "x").map(String.init)
        guard parts.count == 2,
              let width = Int(parts[0]), let height = Int(parts[1]),
              width > 0, height > 0 else {
            throw CLIError.usage("scale: bad WxH '\(target)'")
        }
        return (width, height)
    }
}
