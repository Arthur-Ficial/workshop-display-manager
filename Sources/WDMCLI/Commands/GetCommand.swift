import WDMCore
import WDMSystem

public enum GetCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let useJSON = args.contains("--json")
        let positional = Args.positional(args)
        guard let alias = positional.first else {
            throw CLIError.usage("usage: wdm get <id|main> [field]")
        }
        let snapshot = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snapshot)
        guard let display = snapshot.display(id: id) else {
            throw CLIError.displayNotFound(id)
        }

        if useJSON {
            deps.stdout.write(try JSONFormatter.encode(display))
            return ExitCodes.success
        }

        let field = positional.dropFirst().first
        if let f = field {
            deps.stdout.writeLine(try fieldValue(of: display, field: f))
        } else {
            deps.stdout.write(SnapshotTableFormatter.format(
                Snapshot(createdAt: snapshot.createdAt, displays: [display])
            ))
        }
        return ExitCodes.success
    }

    private static func fieldValue(of d: DisplayInfo, field: String) throws -> String {
        switch field {
        case "id":        return String(d.id)
        case "name":      return d.name ?? ""
        case "mode":      return d.currentMode.description
        case "origin":    return "\(d.origin.x),\(d.origin.y)"
        case "rotation":  return String(d.rotationDegrees)
        case "main":      return d.isMain ? "true" : "false"
        case "online":    return d.isOnline ? "true" : "false"
        case "mirror":    return d.mirrorSource.map(String.init) ?? ""
        default:          throw CLIError.usage("unknown field: \(field)")
        }
    }
}
