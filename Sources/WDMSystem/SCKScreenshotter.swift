import Foundation
import CoreGraphics

/// Real screenshotter. Maps `CGDirectDisplayID` to the OS-bundled
/// `/usr/sbin/screencapture` tool's 1-based display index and shells out.
/// `screencapture` uses ScreenCaptureKit internally and works for every
/// display macOS knows about — real, virtual, or AirPlay.
///
/// Documented exception to the project's "no shell-outs" rule, mirroring
/// `wdm sleep`'s use of an OS-bundled IOKit facility. The Swift Concurrency
/// path through `SCShareableContent.current` + `SCScreenshotManager.captureImage`
/// from a synchronous CLI entry point leaks continuations under load on
/// macOS 26 — the OS tool sidesteps that entirely.
public final class SCKScreenshotter: Screenshotter, @unchecked Sendable {
    public init() {}

    public func capture(displayID: UInt32, to url: URL) throws {
        let idx = try ScreenCaptureDisplayIndex.screencaptureIndex(
            displayID: CGDirectDisplayID(displayID)
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-D", "\(idx)", "-x", "-t", "png", url.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ProviderError.ioError(
                "screenshot: /usr/sbin/screencapture -D \(idx) exited \(process.terminationStatus)"
            )
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProviderError.ioError("screenshot: no file at \(url.path)")
        }
    }
}
