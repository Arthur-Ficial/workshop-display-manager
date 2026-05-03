import Foundation
import WDMKit

/// `wdm hotkeys` — user-facing surface for global keyboard shortcuts.
public enum HotkeysCommand {
    static let label = "com.fullstackoptimization.wdm.hotkeys"

    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        let store = KeybindingStore.resolve(env: deps.processEnv)
        switch pos.first {
        case "list", nil:                  return try list(store: store, deps: deps)
        case "set", "add":                 return try set(args: pos, store: store, deps: deps)
        case "delete", "unbind", "remove": return try delete(args: pos, store: store, deps: deps)
        case "reset":                      return try reset(store: store, deps: deps)
        case "daemon":                     return try daemon(args: args, store: store, deps: deps)
        case "install":                    return try install(deps: deps)
        case "uninstall":                  return try uninstall(deps: deps)
        case "status":                     return try status(store: store, deps: deps)
        default:
            throw WDMError.usage("usage: wdm hotkeys <list|set|delete|reset|daemon|install|uninstall|status>")
        }
    }

    private static func list(store: KeybindingStore, deps: CLIDeps) throws -> Int32 {
        for kb in try WDMController.keybindings.list(store: store) {
            deps.stdout.writeLine("\(kb.chord)\t\(kb.command)\t\(kb.enabled ? "enabled" : "disabled")")
        }
        return ExitCodes.success
    }

    private static func set(args: [String], store: KeybindingStore, deps: CLIDeps) throws -> Int32 {
        guard args.count >= 3 else {
            throw WDMError.usage("usage: wdm hotkeys set <chord> <command...>")
        }
        let chord = try WDMController.keybindings.normalize(args[1])
        let command = args.dropFirst(2).joined(separator: " ")
        try WDMController.keybindings.upsert(Keybinding(chord: chord, command: command), store: store)
        deps.stderr.writeLine("hotkeys: bound \(chord) → \(command)")
        return ExitCodes.success
    }

    private static func delete(args: [String], store: KeybindingStore, deps: CLIDeps) throws -> Int32 {
        guard args.count >= 2 else { throw WDMError.usage("usage: wdm hotkeys delete <chord>") }
        let chord = try WDMController.keybindings.normalize(args[1])
        let removed = try WDMController.keybindings.remove(chord: chord, store: store)
        if !removed {
            deps.stderr.writeLine("hotkeys: no binding for '\(chord)'")
            return ExitCodes.profileNotFound
        }
        deps.stderr.writeLine("hotkeys: removed \(chord)")
        return ExitCodes.success
    }

    private static func reset(store: KeybindingStore, deps: CLIDeps) throws -> Int32 {
        try WDMController.keybindings.installDefaults(store: store)
        deps.stderr.writeLine("hotkeys: reset to \(Keybinding.defaults.count) defaults")
        return ExitCodes.success
    }

    private static func daemon(args: [String], store: KeybindingStore, deps: CLIDeps) throws -> Int32 {
        let max = Args.flagInt(args, name: "--max-events")
        let bindings = try WDMController.keybindings.list(store: store)
        let registrar = HotkeyRegistrarFactory.make(env: deps.processEnv)
        let dispatch = HotkeyDispatcherFactory.make(env: deps.processEnv)
        let outcome = try WDMController.hotkeys.runDaemon(
            bindings: bindings,
            registrar: registrar,
            maxEvents: max,
            dispatch: dispatch
        )
        for chord in outcome.skipped {
            deps.stderr.writeLine("hotkeys: skip '\(chord)' — already taken by another app")
        }
        deps.stderr.writeLine("hotkeys: registered \(outcome.registered) of \(bindings.filter(\.enabled).count) bindings")
        return ExitCodes.success
    }

    private static func install(deps: CLIDeps) throws -> Int32 {
        let target = LaunchAgentInstaller.defaultPlistURL(forLabel: label, env: deps.processEnv)
        let exec = deps.processEnv["WDM_HOTKEYS_EXEC"] ?? "/usr/local/bin/wdm"
        try LaunchAgentInstaller.write(
            to: target, label: label, executablePath: exec,
            args: ["hotkeys", "daemon"]
        )
        deps.stderr.writeLine("hotkeys: wrote \(target.path)")
        deps.stderr.writeLine("hotkeys: load with `launchctl load \(target.path)`")
        return ExitCodes.success
    }

    private static func uninstall(deps: CLIDeps) throws -> Int32 {
        let target = LaunchAgentInstaller.defaultPlistURL(forLabel: label, env: deps.processEnv)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
            deps.stderr.writeLine("hotkeys: removed \(target.path)")
        } else {
            deps.stderr.writeLine("hotkeys: nothing to remove at \(target.path)")
        }
        return ExitCodes.success
    }

    private static func status(store: KeybindingStore, deps: CLIDeps) throws -> Int32 {
        let target = LaunchAgentInstaller.defaultPlistURL(forLabel: label, env: deps.processEnv)
        let installed = FileManager.default.fileExists(atPath: target.path)
        let count = try WDMController.keybindings.list(store: store).count
        deps.stdout.writeLine("daemon: \(installed ? "installed at \(target.path)" : "not installed")")
        deps.stdout.writeLine("config: \(count) binding\(count == 1 ? "" : "s") in \(store.url.path)")
        return ExitCodes.success
    }
}
