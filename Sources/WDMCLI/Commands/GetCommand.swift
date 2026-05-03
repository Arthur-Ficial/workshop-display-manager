import Foundation
import WDMCore

public enum GetCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let useJSON = args.contains("--json")
        let positional = Args.positional(args)
        guard let alias = positional.first else {
            throw CLIError.usage("usage: wdm get <id|main> [field]")
        }
        let display = try deps.controller.get(alias)

        if useJSON {
            deps.stdout.write(try JSONFormatter.encode(display))
            return ExitCodes.success
        }

        let field = positional.dropFirst().first
        if let f = field {
            deps.stdout.writeLine(try fieldValue(deps: deps, alias: alias, field: f))
        } else {
            deps.stdout.write(SnapshotTableFormatter.format(singleDisplaySnapshot(display)))
        }
        return ExitCodes.success
    }

    private static func fieldValue(deps: CLIDeps, alias: String, field: String) throws -> String {
        text(try deps.controller.get(alias, field: parse(field)))
    }

    private static func parse(_ field: String) throws -> WDMDisplayField {
        switch field {
        case "id":       return .id
        case "name":     return .name
        case "mode":     return .mode
        case "origin":   return .origin
        case "rotation": return .rotation
        case "main":     return .main
        case "online":   return .online
        case "mirror":   return .mirror
        default:          throw CLIError.usage("unknown field: \(field)")
        }
    }

    private static func text(_ value: WDMFieldValue) -> String {
        switch value {
        case .bool(let value):         return value ? "true" : "false"
        case .mode(let mode):          return mode.description
        case .point(let point):        return "\(point.x),\(point.y)"
        case .text(let value):         return value
        case .uint(let value):         return String(value)
        case .optionalUInt(let value): return value.map(String.init) ?? ""
        }
    }

    private static func singleDisplaySnapshot(_ display: DisplayInfo) -> Snapshot {
        Snapshot(createdAt: Date(timeIntervalSince1970: 0), displays: [display])
    }
}
