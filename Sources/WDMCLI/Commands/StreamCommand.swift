import Foundation
import WDMCore
import WDMSystem

public enum StreamCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first, !alias.isEmpty else {
            throw CLIError.usage(
                "usage: wdm stream <id|main> [--hls <dir>|--rtmp <url>] --duration <sec>"
            )
        }
        guard let durStr = Args.flagString(args, name: "--duration"),
              let dur = Int(durStr), dur > 0 else {
            throw CLIError.usage(
                "usage: wdm stream <id|main> [--hls <dir>|--rtmp <url>] --duration <sec>"
            )
        }
        let mode: StreamMode
        let target: String
        if let hls = Args.flagString(args, name: "--hls"), !hls.isEmpty {
            mode = .hls
            target = hls
        } else if let rtmp = Args.flagString(args, name: "--rtmp"), !rtmp.isEmpty {
            mode = .rtmp
            target = rtmp
        } else {
            throw CLIError.usage(
                "usage: wdm stream <id|main> --hls <dir> | --rtmp <url> + --duration <sec>"
            )
        }

        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snap)
        deps.stderr.writeLine(
            "wdm: streaming display \(id) for \(dur)s via \(mode.rawValue) → \(target)"
        )
        try deps.streamer.stream(displayID: id, target: target, mode: mode, durationSec: dur)
        deps.stderr.writeLine("wdm: stream complete")
        return ExitCodes.success
    }
}
