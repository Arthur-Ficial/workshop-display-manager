import Foundation
import WDMCore
import WDMSystem

public enum CLIRunner {
    public static func run(
        args: [String],
        env: [String: String],
        stdout: OutputWriter,
        stderr: OutputWriter
    ) -> Int32 {
        guard let sub = args.first else {
            stderr.writeLine("usage: wdm <command> [args]   try 'wdm help'")
            return ExitCodes.usage
        }
        if sub == "help" || sub == "--help" || sub == "-h" {
            stdout.write(HelpText.body)
            return ExitCodes.success
        }
        if sub == "version" || sub == "--version" {
            stdout.writeLine("wdm \(WDMCore.version)")
            return ExitCodes.success
        }

        let rest = Array(args.dropFirst())

        let provider: DisplayProvider
        do {
            provider = try DisplayProviderFactory.make(env: env)
        } catch {
            stderr.writeLine("error: \(error)")
            return ExitCodes.generic
        }
        let profileStore = ProfileStore.resolve(env: env)
        let confirmer: Confirmer = env["WDM_AUTO_CONFIRM"] == "1"
            ? AutoYesConfirmer()
            : StdinConfirmer(prompt: "keep change?", stderr: stderr)
        let deps = CLIDeps(
            provider: provider, profileStore: profileStore,
            confirmer: confirmer,
            stdout: stdout, stderr: stderr
        )

        do {
            switch sub {
            case "list":     return try ListCommand.run(args: rest, deps: deps)
            case "get":      return try GetCommand.run(args: rest, deps: deps)
            case "modes":    return try ModesCommand.run(args: rest, deps: deps)
            case "save":     return try SaveCommand.run(args: rest, deps: deps)
            case "restore":  return try RestoreCommand.run(args: rest, deps: deps)
            case "profiles": return try ProfilesCommand.run(args: rest, deps: deps)
            case "mode":     return try ModeCommand.run(args: rest, deps: deps)
            case "main":     return try MainCommand.run(args: rest, deps: deps)
            case "mirror":   return try MirrorCommand.run(args: rest, deps: deps)
            case "unmirror": return try UnmirrorCommand.run(args: rest, deps: deps)
            case "move":     return try MoveCommand.run(args: rest, deps: deps)
            case "rotate":   return try RotateCommand.run(args: rest, deps: deps)
            case "switch":   return try SwitchCommand.run(args: rest, deps: deps)
            case "cycle":    return try CycleCommand.run(args: rest, deps: deps)
            case "brightness": return try BrightnessCommand.run(args: rest, deps: deps)
            default:
                stderr.writeLine("unknown command: \(sub)")
                return ExitCodes.usage
            }
        } catch let error as CLIError {
            stderr.writeLine("error: \(error.message)")
            return error.exitCode
        } catch let error as ProviderError {
            return Self.handleProviderError(error, stderr: stderr)
        } catch {
            stderr.writeLine("error: \(error)")
            return ExitCodes.generic
        }
    }

    private static func handleProviderError(_ error: ProviderError, stderr: OutputWriter) -> Int32 {
        switch error {
        case .displayNotFound(let id):
            stderr.writeLine("error: display not found: \(id)")
            return ExitCodes.displayNotFound
        case .modeNotSupported:
            stderr.writeLine("error: mode not supported")
            return ExitCodes.modeNotSupported
        case .invalidRotation(let d):
            stderr.writeLine("error: invalid rotation: \(d)")
            return ExitCodes.usage
        case .brightnessUnsupported(let id):
            stderr.writeLine("error: brightness not supported on display \(id)")
            return ExitCodes.modeNotSupported
        case .brightnessOutOfRange(let v):
            stderr.writeLine("error: brightness out of range (0…1): \(v)")
            return ExitCodes.usage
        case .configurationFailed(let s):
            stderr.writeLine("error: \(s)")
            return ExitCodes.coreGraphicsError
        case .ioError(let s):
            stderr.writeLine("error: \(s)")
            return ExitCodes.ioError
        }
    }
}
