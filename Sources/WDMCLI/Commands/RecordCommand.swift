import Foundation

public enum RecordCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw CLIError.usage("usage: wdm record <id|main> --out <path> --duration <seconds>")
        }
        guard let outPath = Args.flagString(args, name: "--out"), !outPath.isEmpty else {
            throw CLIError.usage("usage: wdm record <id|main> --out <path> --duration <seconds>")
        }
        guard let durStr = Args.flagString(args, name: "--duration"),
              let dur = Int(durStr), dur > 0 else {
            throw CLIError.usage("usage: wdm record <id|main> --out <path> --duration <seconds>")
        }
        let id = try deps.controller.get(alias).id
        let url = URL(fileURLWithPath: outPath)
        deps.stderr.writeLine("wdm: recording display \(id) for \(dur)s → \(url.path)")
        try deps.controller.record(alias, to: url, durationSec: dur, using: deps.recorder)
        deps.stderr.writeLine("wdm: recording complete")
        return ExitCodes.success
    }
}
