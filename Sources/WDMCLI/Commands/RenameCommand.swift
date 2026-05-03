import Foundation
import WDMCore
import WDMSystem

/// `wdm rename <id> <name> [--system] [--remove]`
///
/// Default mode = wdm-only alias map (cheap, no privileges, survives
/// reboot via stable EDID id). `--system` mode writes a real OS override
/// plist so System Settings + every app pick up the new name.
public enum RenameCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        let isSystem = args.contains("--system")
        let isRemove = args.contains("--remove")
        guard let alias = pos.first else {
            throw CLIError.usage(
                "usage: wdm rename <id|main> <name> [--system]\n" +
                "       wdm rename <id|main> --remove"
            )
        }
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snap)
        guard snap.display(id: id) != nil else {
            throw CLIError.displayNotFound(id)
        }
        let edid = try? deps.provider.edid(for: id)
        let store = DisplayAliasStore.resolve(env: deps.processEnv)
        let key = DisplayAliasStore.key(forID: id, edidStableID: edid?.stableID)

        if isRemove {
            let removed = try store.remove(key: key)
            if !removed {
                deps.stderr.writeLine("rename: no alias for display \(id)")
                return ExitCodes.profileNotFound
            }
            deps.stderr.writeLine("rename: removed alias for display \(id)")
            return ExitCodes.success
        }

        guard pos.count >= 2 else {
            throw CLIError.usage("usage: wdm rename <id> <name> [--system]")
        }
        let name = pos.dropFirst().joined(separator: " ")
        try store.upsert(key: key, name: name)
        deps.stderr.writeLine("rename: set alias for display \(id) → '\(name)'")

        if isSystem {
            guard let edid else {
                deps.stderr.writeLine(
                    "rename --system: display \(id) has no EDID; alias-only rename is the best we can do."
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
                    productName: name
                )
            } catch {
                throw CLIError.ioError("\(error)")
            }
            deps.stderr.writeLine(
                "rename --system: wrote override plist; logout/restart for the OS to pick it up"
            )
        }
        return ExitCodes.success
    }
}
