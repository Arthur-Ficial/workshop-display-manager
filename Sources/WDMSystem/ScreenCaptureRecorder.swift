import Foundation
import CoreGraphics

/// Real recorder. Maps `CGDirectDisplayID` to `screencapture`'s 1-based
/// display index, then shells out to `/usr/sbin/screencapture -v -V <sec> -D <idx>`.
/// Output is .mov (QuickTime, H.264). Same OS-bundled tool we already use for
/// `wdm screenshot`; same documented "no-shell-outs" exception.
public final class ScreenCaptureRecorder: Recorder, @unchecked Sendable {
    public init() {}

    public func record(displayID: UInt32, to url: URL, durationSec: Int) throws {
        var n: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &n)
        var ids = Array<CGDirectDisplayID>(repeating: 0, count: Int(n))
        var count: UInt32 = n
        CGGetActiveDisplayList(n, &ids, &count)
        guard let zeroBased = ids.firstIndex(of: CGDirectDisplayID(displayID)) else {
            throw ProviderError.displayNotFound(displayID)
        }
        let idx = zeroBased + 1     // screencapture is 1-based

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = [
            "-v",                       // record video
            "-V", "\(durationSec)",     // duration in seconds
            "-D", "\(idx)",             // display index
            "-x",                       // silent (no shutter sound)
            url.path,
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ProviderError.ioError(
                "record: /usr/sbin/screencapture -v -D \(idx) exited \(process.terminationStatus)"
            )
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProviderError.ioError("record: no file at \(url.path)")
        }
    }
}
