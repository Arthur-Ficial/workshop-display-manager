import Foundation
import CoreGraphics

/// Real `Streamer` shelling out to `/opt/homebrew/bin/ffmpeg` (or `/usr/bin/env ffmpeg`).
/// Maps the wdm `CGDirectDisplayID` to ffmpeg's avfoundation 1-based screen
/// index by parsing `ffmpeg -f avfoundation -list_devices true -i ""`.
///
/// **License:** ffmpeg as runtime-only dependency (Process-spawn, not linked)
/// is fine under LGPL or GPL. Don't bundle. Documented in README.
public final class FFmpegStreamer: Streamer, @unchecked Sendable {
    public init() {}

    public func stream(
        displayID: UInt32, target: String, mode: StreamMode, durationSec: Int
    ) throws {
        let ffmpeg = locateFFmpeg() ?? "/opt/homebrew/bin/ffmpeg"
        guard FileManager.default.isExecutableFile(atPath: ffmpeg) else {
            throw ProviderError.configurationFailed(
                "stream: ffmpeg not found. Install via `brew install ffmpeg`."
            )
        }

        // Map CGDirectDisplayID → avfoundation 1-based screen index.
        // The avfoundation indexing is *not* contractually equal to
        // CGGetActiveDisplayList; we resolve by name where possible, falling
        // back to the order ffmpeg reports.
        let avIdx = try discoverAvfoundationIndex(ffmpeg: ffmpeg, displayID: displayID)

        let outputArgs: [String]
        switch mode {
        case .hls:
            // target is a directory; produce <target>/index.m3u8 + segments.
            try? FileManager.default.createDirectory(
                at: URL(fileURLWithPath: target), withIntermediateDirectories: true
            )
            let m3u8 = (target as NSString).appendingPathComponent("index.m3u8")
            outputArgs = [
                "-f", "hls",
                "-hls_time", "2",
                "-hls_list_size", "0",
                "-hls_flags", "delete_segments+independent_segments",
                m3u8,
            ]
        case .rtmp:
            outputArgs = ["-f", "flv", target]
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ffmpeg)
        proc.arguments = [
            "-y",
            "-f", "avfoundation",
            "-framerate", "30",
            "-capture_cursor", "1",
            "-i", "\(avIdx):none",
            "-t", "\(durationSec)",
            "-c:v", "h264_videotoolbox",
            "-pix_fmt", "yuv420p",
        ] + outputArgs
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw ProviderError.ioError(
                "stream: ffmpeg exited \(proc.terminationStatus)"
            )
        }
    }

    private func locateFFmpeg() -> String? {
        for path in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    /// Parse `ffmpeg -f avfoundation -list_devices true -i ""` to find the
    /// 1-based screen index whose name corresponds to the given displayID.
    /// Falls back to position in CGGetActiveDisplayList if names don't help.
    private func discoverAvfoundationIndex(ffmpeg: String, displayID: UInt32) throws -> Int {
        // Best-effort: ffmpeg's avfoundation lists screens after cameras with
        // captions like "Capture screen 0", "Capture screen 1", … in the order
        // CG enumerates them. We use that order; verify a screen entry exists.
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ffmpeg)
        proc.arguments = ["-f", "avfoundation", "-list_devices", "true", "-i", ""]
        let stderrPipe = Pipe()
        proc.standardError = stderrPipe
        proc.standardOutput = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        let raw = String(
            data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        // Lines look like:  [AVFoundation indev @ 0x14c609ee0] [5] Capture screen 0
        var screens: [(idx: Int, label: String)] = []
        for line in raw.split(separator: "\n").map(String.init) {
            guard line.contains("Capture screen") else { continue }
            // Pull the "[N]" before the label.
            if let openBracket = line.range(of: "[", options: .backwards),
               let closeBracket = line.range(of: "]", options: .backwards),
               openBracket.lowerBound < closeBracket.lowerBound {
                // Walk every "[N]" — pick the LAST one that's just digits.
                let parts = line.split(separator: "[").map { $0.split(separator: "]").first.map(String.init) ?? "" }
                for p in parts.reversed() {
                    if let n = Int(p) {
                        screens.append((idx: n, label: line))
                        break
                    }
                }
                _ = openBracket; _ = closeBracket
            }
        }
        // Match by position: the Nth screen reported by ffmpeg = position of
        // the displayID in CGGetActiveDisplayList.
        var n: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &n)
        var ids = Array<CGDirectDisplayID>(repeating: 0, count: Int(n))
        var count: UInt32 = n
        CGGetActiveDisplayList(n, &ids, &count)
        guard let cgPos = ids.firstIndex(of: CGDirectDisplayID(displayID)) else {
            throw ProviderError.displayNotFound(displayID)
        }
        guard cgPos < screens.count else {
            throw ProviderError.configurationFailed(
                "stream: ffmpeg avfoundation reports \(screens.count) screen(s); display \(displayID) is at CG position \(cgPos)"
            )
        }
        return screens[cgPos].idx
    }
}
