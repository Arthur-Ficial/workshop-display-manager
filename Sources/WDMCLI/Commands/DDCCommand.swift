import Foundation
import WDMCore
import WDMSystem

/// `wdm ddc` — control external monitors over DDC/CI.
/// Subcommands map to standard MCCS VCP codes; `get`/`set` expose the
/// raw VCP space for monitor-specific features.
public enum DDCCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        let provider = DDCProviderFactory.make(env: deps.processEnv)
        switch pos.first {
        case "brightness":
            return try percentVerb(args: pos, vcp: DDCCodes.brightness,
                                   provider: provider, deps: deps)
        case "contrast":
            return try percentVerb(args: pos, vcp: DDCCodes.contrast,
                                   provider: provider, deps: deps)
        case "volume":
            return try percentVerb(args: pos, vcp: DDCCodes.audioVolume,
                                   provider: provider, deps: deps)
        case "mute":
            return try muteVerb(args: pos, provider: provider, deps: deps)
        case "input":
            return try inputVerb(args: pos, provider: provider, deps: deps)
        case "get":
            return try rawGet(args: pos, provider: provider, deps: deps)
        case "set":
            return try rawSet(args: pos, provider: provider, deps: deps)
        default:
            throw CLIError.usage(
                "usage: wdm ddc <brightness|contrast|volume|mute|input|get|set> <id> [...]"
            )
        }
    }

    // MARK: - shared helpers

    /// Read or write a 0..1 percent verb (brightness, contrast, volume).
    /// Stored on the wire as 0..100 — universal for MCCS.
    private static func percentVerb(
        args: [String], vcp: UInt8,
        provider: DDCProvider, deps: CLIDeps
    ) throws -> Int32 {
        guard args.count >= 2 else {
            throw CLIError.usage("usage: wdm ddc \(args[0]) <id> [0..1]")
        }
        let id = try resolveID(args[1], deps: deps)
        if args.count == 2 {
            let raw = try readChecked(provider: provider, id: id, vcp: vcp)
            let pct = Float(raw) / 100.0
            deps.stdout.writeLine(String(format: "%.2f", pct))
            return ExitCodes.success
        }
        guard let v = Float(args[2]), v >= 0, v <= 1 else {
            throw CLIError.usage("\(args[0]): value must be in 0..1")
        }
        let onWire = UInt16((v * 100).rounded())
        try writeChecked(provider: provider, id: id, vcp: vcp, value: onWire)
        return ExitCodes.success
    }

    private static func muteVerb(
        args: [String], provider: DDCProvider, deps: CLIDeps
    ) throws -> Int32 {
        guard args.count >= 2 else {
            throw CLIError.usage("usage: wdm ddc mute <id> [on|off]")
        }
        let id = try resolveID(args[1], deps: deps)
        if args.count == 2 {
            let raw = try readChecked(provider: provider, id: id, vcp: DDCCodes.audioMute)
            // MCCS: 1 = mute, 2 = unmute
            deps.stdout.writeLine(raw == 1 ? "on" : "off")
            return ExitCodes.success
        }
        let value: UInt16
        switch args[2] {
        case "on", "1", "true":  value = 1
        case "off", "0", "false": value = 2
        default: throw CLIError.usage("mute: must be on|off")
        }
        try writeChecked(provider: provider, id: id, vcp: DDCCodes.audioMute, value: value)
        return ExitCodes.success
    }

    private static func inputVerb(
        args: [String], provider: DDCProvider, deps: CLIDeps
    ) throws -> Int32 {
        guard args.count >= 3 else {
            throw CLIError.usage(
                "usage: wdm ddc input <id> <hdmi1|hdmi2|dp|dp2|usbc|vga|...>"
            )
        }
        let id = try resolveID(args[1], deps: deps)
        guard let code = DDCInputAlias.code(for: args[2]) else {
            throw CLIError.usage(
                "input: unknown source '\(args[2])'. " +
                "Use `wdm ddc set <id> 0x60 <code>` for monitor-specific values."
            )
        }
        try writeChecked(provider: provider, id: id, vcp: DDCCodes.inputSource, value: code)
        return ExitCodes.success
    }

    private static func rawGet(
        args: [String], provider: DDCProvider, deps: CLIDeps
    ) throws -> Int32 {
        guard args.count >= 3 else {
            throw CLIError.usage("usage: wdm ddc get <id> 0xNN")
        }
        let id = try resolveID(args[1], deps: deps)
        guard let vcp = parseVCP(args[2]) else {
            throw CLIError.usage("get: bad VCP code '\(args[2])'")
        }
        let raw = try readChecked(provider: provider, id: id, vcp: vcp)
        deps.stdout.writeLine(String(raw))
        return ExitCodes.success
    }

    private static func rawSet(
        args: [String], provider: DDCProvider, deps: CLIDeps
    ) throws -> Int32 {
        guard args.count >= 4 else {
            throw CLIError.usage("usage: wdm ddc set <id> 0xNN <value>")
        }
        let id = try resolveID(args[1], deps: deps)
        guard let vcp = parseVCP(args[2]) else {
            throw CLIError.usage("set: bad VCP code '\(args[2])'")
        }
        guard let value = UInt16(args[3]) else {
            throw CLIError.usage("set: value must be 0..65535")
        }
        try writeChecked(provider: provider, id: id, vcp: vcp, value: value)
        return ExitCodes.success
    }

    private static func resolveID(_ alias: String, deps: CLIDeps) throws -> UInt32 {
        let snap = try deps.provider.snapshot()
        return try DisplayResolver.resolve(alias, in: snap)
    }

    private static func readChecked(
        provider: DDCProvider, id: UInt32, vcp: UInt8
    ) throws -> UInt16 {
        do {
            return try provider.read(displayID: id, vcp: vcp)
        } catch DDCError.unsupported(let i) {
            throw CLIError.ddcUnsupported(i)
        }
    }

    private static func writeChecked(
        provider: DDCProvider, id: UInt32, vcp: UInt8, value: UInt16
    ) throws {
        do {
            try provider.write(displayID: id, vcp: vcp, value: value)
        } catch DDCError.unsupported(let i) {
            throw CLIError.ddcUnsupported(i)
        }
    }

    private static func parseVCP(_ token: String) -> UInt8? {
        if token.hasPrefix("0x") || token.hasPrefix("0X") {
            return UInt8(token.dropFirst(2), radix: 16)
        }
        return UInt8(token)
    }
}
