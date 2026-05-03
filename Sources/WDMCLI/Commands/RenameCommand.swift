import WDMKit

/// `wdm rename <id> <name> [--system] [--remove]`
public enum RenameCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw WDMError.usage(
                "usage: wdm rename <id|main> <name> [--system]\n" +
                "       wdm rename <id|main> --remove"
            )
        }
        let store = DisplayAliasStore.resolve(env: deps.processEnv)

        if args.contains("--remove") {
            return try runRemove(alias: alias, store: store, deps: deps)
        }
        guard pos.count >= 2 else {
            throw WDMError.usage("usage: wdm rename <id> <name> [--system]")
        }
        let name = pos.dropFirst().joined(separator: " ")
        let outcome = try deps.controller.rename(alias, to: name, store: store)
        deps.stderr.writeLine("rename: set alias for display \(outcome.displayID) → '\(outcome.name)'")

        if args.contains("--system") {
            return try writeSystemOverride(outcome: outcome, deps: deps)
        }
        return ExitCodes.success
    }

    private static func runRemove(alias: String, store: DisplayAliasStore, deps: CLIDeps) throws -> Int32 {
        let id = try deps.controller.get(alias).id
        let removed = try deps.controller.removeRename(alias, store: store)
        if !removed {
            deps.stderr.writeLine("rename: no alias for display \(id)")
            return ExitCodes.profileNotFound
        }
        deps.stderr.writeLine("rename: removed alias for display \(id)")
        return ExitCodes.success
    }

    private static func writeSystemOverride(outcome: WDMController.RenameOutcome, deps: CLIDeps) throws -> Int32 {
        let edid: EDID
        do {
            edid = try deps.controller.edid(String(outcome.displayID))
        } catch {
            deps.stderr.writeLine(
                "rename --system: display \(outcome.displayID) has no EDID; alias-only rename is the best we can do."
            )
            return ExitCodes.modeNotSupported
        }
        let overridesDir = DisplayOverrideWriter.defaultOverridesDir(env: deps.processEnv)
        let vendorID = DisplayOverrideWriter.vendorID(from: edid.manufacturerID)
        do {
            try DisplayOverrideWriter.write(
                overridesDir: overridesDir,
                vendorID: vendorID,
                productID: edid.productCode,
                productName: outcome.name
            )
        } catch {
            throw WDMError.ioError("\(error)")
        }
        deps.stderr.writeLine(
            "rename --system: wrote override plist; logout/restart for the OS to pick it up"
        )
        return ExitCodes.success
    }
}
