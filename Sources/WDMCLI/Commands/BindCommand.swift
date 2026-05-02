import Foundation
import WDMCore
import WDMSystem

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
        case "list":
            let all = try store.load()
            for kb in all {
                deps.stdout.writeLine("\(kb.chord)\t\(kb.command)\t\(kb.enabled ? "enabled" : "disabled")")
            }
            return ExitCodes.success
        case "defaults":
            try store.save(Keybinding.defaults)
            deps.stderr.writeLine("wdm: installed \(Keybinding.defaults.count) default bindings → \(store.url.path)")
            return ExitCodes.success
        case "remove", "unbind":
            guard pos.count >= 2 else {
                throw CLIError.usage("usage: wdm bind unbind <chord>")
            }
            guard let chord = Keybinding.normalize(pos[1]) else {
                throw CLIError.usage("wdm bind: malformed chord '\(pos[1])'")
            }
            let removed = try store.remove(chord: chord)
            if !removed {
                deps.stderr.writeLine("wdm bind: no binding for chord '\(chord)'")
                return ExitCodes.profileNotFound
            }
            deps.stderr.writeLine("wdm bind: removed \(chord)")
            return ExitCodes.success
        case nil:
            deps.stdout.writeLine("usage: wdm bind <subcommand>")
            deps.stdout.writeLine("subcommands:")
            deps.stdout.writeLine("  add <chord> <command...>   add or replace a binding")
            deps.stdout.writeLine("  unbind <chord>             remove a binding")
            deps.stdout.writeLine("  list                       print all bindings")
            deps.stdout.writeLine("  defaults                   install the sensible-default set")
            return ExitCodes.success
        default:
            // Treat first positional as a chord, rest as the command. This
            // supports both `wdm bind add cmd+s switch` and `wdm bind cmd+s switch`.
            var chordToken = pos[0]
            var cmdTokens = Array(pos.dropFirst())
            if pos[0] == "add" {
                guard pos.count >= 3 else {
                    throw CLIError.usage("usage: wdm bind add <chord> <command...>")
                }
                chordToken = pos[1]
                cmdTokens = Array(pos.dropFirst(2))
            }
            guard let chord = Keybinding.normalize(chordToken) else {
                throw CLIError.usage("wdm bind: malformed chord '\(chordToken)'")
            }
            guard !cmdTokens.isEmpty else {
                throw CLIError.usage("usage: wdm bind <chord> <command...>")
            }
            let kb = Keybinding(chord: chord, command: cmdTokens.joined(separator: " "))
            try store.upsert(kb)
            deps.stderr.writeLine("wdm bind: \(chord) → \(kb.command)")
            return ExitCodes.success
        }
    }
}
