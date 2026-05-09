import Foundation
import WDMKit

/// `wdm arrange` — bulk arrangement read/write. The companion to the WDMWeb
/// `/arrangement` route.
public enum ArrangeCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        switch pos.first {
        case "list", nil: return try list(args: args, deps: deps)
        case "set":       return try set(args: args, deps: deps)
        case "move":      return try move(args: args, deps: deps)
        default:          throw WDMError.usage("wdm arrange: unknown subcommand '\(pos[0])'")
        }
    }

    private static func list(args: [String], deps: CLIDeps) throws -> Int32 {
        let entries = try deps.controller.arrangement()
        if args.contains("--json") {
            deps.stdout.write(try JSONFormatter.encode(entries))
        } else {
            for e in entries {
                let rot = e.rotationDegrees.map { "rot=\($0)" } ?? ""
                deps.stdout.writeLine("\(e.id)\t\(e.origin.x)\t\(e.origin.y)\t\(rot)")
            }
        }
        return ExitCodes.success
    }

    /// `wdm arrange set @-` reads the JSON plan from stdin, `wdm arrange set @<path>`
    /// from a file. The plan is the same shape `arrange list --json` produces.
    private static func set(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw WDMError.usage("usage: wdm arrange set @-|@<path>")
        }
        let token = pos[1]
        let data: Data
        if token == "@-" {
            data = FileHandle.standardInput.availableData
        } else if token.hasPrefix("@") {
            data = try Data(contentsOf: URL(fileURLWithPath: String(token.dropFirst())))
        } else {
            throw WDMError.usage("arrange set: source must start with '@'")
        }
        let entries = try JSONDecoder().decode([ArrangementEntry].self, from: data)
        let confirmer = MutationDispatch.pickConfirmer(deps: deps, args: args)
        let result = try deps.controller.setArrangement(entries, confirmer: confirmer)
        return MutationDispatch.mapResult(result, deps: deps)
    }

    /// Shorthand: `wdm arrange move <id1> <x1> <y1> [<id2> <x2> <y2>] ...`
    /// Triple-positional sequences avoid the need to hand-craft JSON.
    private static func move(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Array(Args.positional(args).dropFirst())
        guard pos.count >= 3, pos.count % 3 == 0 else {
            throw WDMError.usage("usage: wdm arrange move <id> <x> <y> [<id> <x> <y> ...]")
        }
        var entries: [ArrangementEntry] = []
        for triple in stride(from: 0, to: pos.count, by: 3) {
            guard let id = UInt32(pos[triple]),
                  let x = Int(pos[triple + 1]),
                  let y = Int(pos[triple + 2]) else {
                throw WDMError.usage("arrange move: triple #\(triple/3 + 1) is not <id> <x> <y> integers")
            }
            entries.append(ArrangementEntry(id: id, origin: Point(x: x, y: y)))
        }
        let confirmer = MutationDispatch.pickConfirmer(deps: deps, args: args)
        let result = try deps.controller.setArrangement(entries, confirmer: confirmer)
        return MutationDispatch.mapResult(result, deps: deps)
    }
}
