import Foundation
import WDMCore
import WDMSystem

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
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snap)
        let url = URL(fileURLWithPath: outPath)
        deps.stderr.writeLine("wdm: recording display \(id) for \(dur)s → \(url.path)")
        try deps.recorder.record(displayID: id, to: url, durationSec: dur)
        deps.stderr.writeLine("wdm: recording complete")
        return ExitCodes.success
    }
}
