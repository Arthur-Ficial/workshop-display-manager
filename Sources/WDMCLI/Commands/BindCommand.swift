import WDMKit

/// Manage keybindings: bind / unbind / list / install-defaults.
/// **NOTE:** this command stores bindings in
/// `~/.config/wdm/keybindings.json`. The hotkey *listener* daemon that
/// dispatches them at runtime is a separate follow-up
/// (`wdm hotkeys daemon`); this command is the configuration layer.
public enum BindCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        let store = KeybindingStore.resolve(env: deps.processEnv)
        switch pos.first {
        case "list":           return try runList(store: store, deps: deps)
        case "defaults":       return try runDefaults(store: store, deps: deps)
        case "remove", "unbind": return try runRemove(pos: pos, store: store, deps: deps)
        case nil:              return printUsage(deps: deps)
        default:               return try runUpsert(pos: pos, store: store, deps: deps)
        }
    }

    private static func runList(store: KeybindingStore, deps: CLIDeps) throws -> Int32 {
        for kb in try WDMController.keybindings.list(store: store) {
            deps.stdout.writeLine("\(kb.chord)\t\(kb.command)\t\(kb.enabled ? "enabled" : "disabled")")
        }
        return ExitCodes.success
    }

    private static func runDefaults(store: KeybindingStore, deps: CLIDeps) throws -> Int32 {
        try WDMController.keybindings.installDefaults(store: store)
        deps.stderr.writeLine(
            "wdm: installed \(Keybinding.defaults.count) default bindings → \(store.url.path)"
        )
        return ExitCodes.success
    }

    private static func runRemove(pos: [String], store: KeybindingStore, deps: CLIDeps) throws -> Int32 {
        guard pos.count >= 2 else { throw WDMError.usage("usage: wdm bind unbind <chord>") }
        let chord = try WDMController.keybindings.normalize(pos[1])
        let removed = try WDMController.keybindings.remove(chord: chord, store: store)
        if !removed {
            deps.stderr.writeLine("wdm bind: no binding for chord '\(chord)'")
            return ExitCodes.profileNotFound
        }
        deps.stderr.writeLine("wdm bind: removed \(chord)")
        return ExitCodes.success
    }

    private static func runUpsert(pos: [String], store: KeybindingStore, deps: CLIDeps) throws -> Int32 {
        var chordToken = pos[0]
        var cmdTokens = Array(pos.dropFirst())
        if pos[0] == "add" {
            guard pos.count >= 3 else { throw WDMError.usage("usage: wdm bind add <chord> <command...>") }
            chordToken = pos[1]
            cmdTokens = Array(pos.dropFirst(2))
        }
        let chord = try WDMController.keybindings.normalize(chordToken)
        guard !cmdTokens.isEmpty else { throw WDMError.usage("usage: wdm bind <chord> <command...>") }
        let kb = Keybinding(chord: chord, command: cmdTokens.joined(separator: " "))
        try WDMController.keybindings.upsert(kb, store: store)
        deps.stderr.writeLine("wdm bind: \(chord) → \(kb.command)")
        return ExitCodes.success
    }

    private static func printUsage(deps: CLIDeps) -> Int32 {
        deps.stdout.writeLine("usage: wdm bind <subcommand>")
        deps.stdout.writeLine("subcommands:")
        deps.stdout.writeLine("  add <chord> <command...>   add or replace a binding")
        deps.stdout.writeLine("  unbind <chord>             remove a binding")
        deps.stdout.writeLine("  list                       print all bindings")
        deps.stdout.writeLine("  defaults                   install the sensible-default set")
        return ExitCodes.success
    }
}
