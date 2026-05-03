import Foundation
import WDMCore
import WDMSystem

public enum StreamCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        if args.contains("--help") || args.contains("-h") {
            printUsage(deps: deps)
            return ExitCodes.success
        }

        let pos = Args.positional(args)
        guard let alias = pos.first, !alias.isEmpty else {
            throw CLIError.usage(usageLine())
        }
        guard let durStr = Args.flagString(args, name: "--duration"),
              let dur = Int(durStr), dur > 0 else {
            throw CLIError.usage(usageLine())
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
            throw CLIError.usage(usageLine())
        }

        let options = try parseOptions(args)
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snap)

        let json = args.contains("--json")
        let quiet = args.contains("--quiet")

        if !quiet {
            deps.stderr.writeLine(
                "wdm: streaming display \(id) for \(dur)s via \(mode.rawValue) → \(target)"
            )
        }
        try deps.streamer.stream(
            displayID: id, target: target, mode: mode,
            durationSec: dur, options: options
        )
        if !quiet {
            deps.stderr.writeLine("wdm: stream complete")
        }

        if json {
            deps.stdout.writeLine(formatJSON(
                id: id, target: target, mode: mode, dur: dur, options: options
            ))
        }
        return ExitCodes.success
    }

    // MARK: - flag parsing

    private static func parseOptions(_ args: [String]) throws -> StreamOptions {
        let segDur: Int
        if let s = Args.flagString(args, name: "--segment-duration") {
            guard let v = Int(s), v > 0 else {
                throw CLIError.usage("--segment-duration must be a positive integer (got '\(s)')")
            }
            segDur = v
        } else {
            segDur = StreamOptions.default.segmentDurationSec
        }

        let fr: Int
        if let s = Args.flagString(args, name: "--framerate") {
            guard let v = Int(s), v > 0 else {
                throw CLIError.usage("--framerate must be a positive integer (got '\(s)')")
            }
            fr = v
        } else {
            fr = StreamOptions.default.framerate
        }

        let showCursor: Bool
        if args.contains("--no-cursor") {
            showCursor = false
        } else {
            showCursor = StreamOptions.default.showCursor
        }

        let bitrate: Int?
        if let s = Args.flagString(args, name: "--bitrate") {
            guard let v = Int(s), v > 0 else {
                throw CLIError.usage("--bitrate must be a positive integer (kbps), got '\(s)'")
            }
            bitrate = v
        } else {
            bitrate = nil
        }

        return StreamOptions(
            segmentDurationSec: segDur,
            framerate: fr,
            showCursor: showCursor,
            bitrateKbps: bitrate
        )
    }

    // MARK: - output

    private static func formatJSON(
        id: UInt32, target: String, mode: StreamMode, dur: Int, options: StreamOptions
    ) -> String {
        var fields: [String] = []
        fields.append("\"display\":\(id)")
        fields.append("\"target\":\"\(target)\"")
        fields.append("\"mode\":\"\(mode.rawValue)\"")
        fields.append("\"duration\":\(dur)")
        fields.append("\"segmentDurationSec\":\(options.segmentDurationSec)")
        fields.append("\"framerate\":\(options.framerate)")
        fields.append("\"showCursor\":\(options.showCursor)")
        if let kbps = options.bitrateKbps {
            fields.append("\"bitrateKbps\":\(kbps)")
        }
        return "{" + fields.joined(separator: ",") + "}"
    }

    private static func usageLine() -> String {
        "usage: wdm stream <id|main> [--hls <dir>|--rtmp <url>] --duration <sec>" +
        " [--segment-duration N] [--framerate N] [--bitrate KBPS] [--no-cursor]" +
        " [--json] [--quiet]"
    }

    private static func printUsage(deps: CLIDeps) {
        deps.stderr.writeLine("wdm stream — live HLS / RTMP broadcast of a display")
        deps.stderr.writeLine("")
        deps.stderr.writeLine("USAGE")
        deps.stderr.writeLine("  wdm stream <id|main> --hls <dir>  --duration <sec> [options]")
        deps.stderr.writeLine("  wdm stream <id|main> --rtmp <url> --duration <sec> [options]")
        deps.stderr.writeLine("")
        deps.stderr.writeLine("OPTIONS")
        deps.stderr.writeLine("  --segment-duration N    HLS segment length in seconds (default 2)")
        deps.stderr.writeLine("  --framerate N           capture FPS (default 30)")
        deps.stderr.writeLine("  --bitrate KBPS          target H.264 bitrate (default: encoder picks)")
        deps.stderr.writeLine("  --no-cursor             omit cursor from the captured frames")
        deps.stderr.writeLine("  --json                  emit machine-parseable status to stdout on completion")
        deps.stderr.writeLine("  --quiet                 silence the stderr progress lines")
        deps.stderr.writeLine("")
        deps.stderr.writeLine("EXAMPLES")
        deps.stderr.writeLine("  wdm stream main --hls /tmp/live --duration 600")
        deps.stderr.writeLine("  wdm stream 2    --hls /tmp/live --duration 30 --framerate 60 --bitrate 8000")
        deps.stderr.writeLine("  wdm stream main --rtmp rtmp://twitch.tv/foo --duration 1800")
    }
}
