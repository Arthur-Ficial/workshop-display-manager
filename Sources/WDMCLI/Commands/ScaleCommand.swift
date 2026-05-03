import WDMCore
import WDMSystem

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
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(pos[0], in: snap)
        let modes = try deps.provider.modes(for: id)

        switch pos[1] {
        case "list":
            return try list(modes: modes, deps: deps, currentID: id, snap: snap)
        case "looks-like":
            guard pos.count >= 3 else {
                throw CLIError.usage("usage: wdm scale <id> looks-like <WxH>")
            }
            return try apply(target: pos[2], modes: modes, id: id, snap: snap, args: args, deps: deps)
        default:
            return try apply(target: pos[1], modes: modes, id: id, snap: snap, args: args, deps: deps)
        }
    }

    private static func list(
        modes: [Mode], deps: CLIDeps, currentID: UInt32, snap: Snapshot
    ) throws -> Int32 {
        let current = snap.display(id: currentID)?.currentMode
        var seen = Set<String>()
        var lines: [String] = []
        for mode in modes.sorted(by: { ($0.width, $0.height) > ($1.width, $1.height) }) {
            let key = "\(mode.width)x\(mode.height)"
            if seen.insert(key).inserted {
                let isCurrent = current.map { $0.width == mode.width && $0.height == mode.height } ?? false
                lines.append("\(key)\t\(isCurrent ? "*" : " ")")
            }
        }
        for line in lines { deps.stdout.writeLine(line) }
        return ExitCodes.success
    }

    private static func apply(
        target: String, modes: [Mode], id: UInt32,
        snap: Snapshot, args: [String], deps: CLIDeps
    ) throws -> Int32 {
        let parts = target.lowercased().split(separator: "x").map(String.init)
        guard parts.count == 2,
              let w = Int(parts[0]), let h = Int(parts[1]),
              w > 0, h > 0 else {
            throw CLIError.usage("scale: bad WxH '\(target)'")
        }
        // Pick the matching mode with the highest refresh rate. If none
        // matches, throw modeNotSupported with a clear message.
        let candidates = modes
            .filter { $0.width == w && $0.height == h }
            .sorted { $0.refreshHz > $1.refreshHz }
        guard let chosen = candidates.first else {
            throw CLIError.modeNotSupported(
                "no mode with logical resolution \(w)x\(h) on display \(id)"
            )
        }
        let label = snap.display(id: id)?.name ?? "display \(id)"
        return try MutationDispatch.dispatch(
            deps: deps, args: args,
            description: "Scaled \(label) to \(chosen.description)"
        ) {
            try deps.provider.setMode(displayID: id, mode: chosen, options: .noConfirm)
        }
    }
}
