import Foundation

/// `wdm hdr <id> [on|off]` — read or toggle HDR on a display.
public enum HDRCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw CLIError.usage("usage: wdm hdr <id|main> [on|off]")
        }
        let id = try deps.controller.get(alias).id
        let provider = HDRProviderFactory.make(env: deps.processEnv)

        if pos.count == 1 {
            do {
                let state = try deps.controller.hdr(alias, using: provider)
                guard let s = state else {
                    deps.stderr.writeLine(
                        "hdr: display \(id) does not support HDR (non-HDR panel, " +
                        "Mac model without HDR pipeline, or driver doesn't expose it)"
                    )
                    return ExitCodes.modeNotSupported
                }
                deps.stdout.writeLine(s ? "on" : "off")
                return ExitCodes.success
            } catch WDMError.modeNotSupported {
                deps.stderr.writeLine("hdr: display \(id) does not support HDR")
                return ExitCodes.modeNotSupported
            }
        }

        let value: Bool
        switch pos[1] {
        case "on", "1", "true":   value = true
        case "off", "0", "false": value = false
        default:
            throw CLIError.usage("hdr: value must be on|off")
        }
        do {
            try deps.controller.setHDR(alias, enabled: value, using: provider)
        } catch WDMError.modeNotSupported {
            deps.stderr.writeLine("hdr: display \(id) does not support HDR")
            return ExitCodes.modeNotSupported
        }
        deps.stderr.writeLine("hdr: display \(id) → \(value ? "on" : "off")")
        return ExitCodes.success
    }
}
