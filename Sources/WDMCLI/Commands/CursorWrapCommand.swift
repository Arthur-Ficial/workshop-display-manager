import Foundation
import CoreGraphics
import WDMCore
import WDMSystem

/// `wdm cursor-wrap` — cyclic cursor wrap across the active arrangement.
///
/// What it does: when the cursor is hugging the rightmost display's right
/// edge (i.e. macOS WindowServer has clamped it there), warp it to the
/// leftmost display's left edge. Symmetric for left/top/bottom. Works
/// for any number of displays and any arrangement. No virtual clone
/// display required.
///
/// What it does NOT do: window-drag across the wrap. WindowServer's
/// compositor clamps windows to the active-display union the same way
/// it clamps the cursor; cyclic wrap is cursor-only. Making windows
/// cross would require Apple's DriverKit graphics-driver entitlement,
/// which is not available to third-party tools.
public enum CursorWrapCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        if args.contains("--help") || args.contains("-h") {
            printUsage(deps: deps)
            return ExitCodes.success
        }

        // Optional bounded run: --duration-ms N. Without it we block until
        // SIGTERM/SIGINT/SIGHUP — same pattern as wdm doctor disconnect.
        let durationMs: Int?
        if let s = Args.flagString(args, name: "--duration-ms") {
            guard let v = Int(s), v > 0 else {
                throw CLIError.usage("cursor-wrap: --duration-ms must be a positive integer (got '\(s)')")
            }
            durationMs = v
        } else {
            durationMs = nil
        }

        deps.stderr.writeLine(
            "wdm cursor-wrap: cyclic wrap active. " +
            "Right-edge → leftmost; left-edge → rightmost; " +
            "top → bottom; bottom → top. Cursor only — windows do not cross."
        )

        let warper = CyclicArrangementWarperRunner()
        installSignalHandlers { warper.stop() }

        try warper.run(durationMs: durationMs)

        deps.stderr.writeLine("wdm cursor-wrap: stopped.")
        return ExitCodes.success
    }

    private static func printUsage(deps: CLIDeps) {
        deps.stderr.writeLine("wdm cursor-wrap — cyclic cursor wrap across the arrangement")
        deps.stderr.writeLine("")
        deps.stderr.writeLine("USAGE")
        deps.stderr.writeLine("  wdm cursor-wrap [--duration-ms N]")
        deps.stderr.writeLine("")
        deps.stderr.writeLine("WHAT IT DOES")
        deps.stderr.writeLine("  Watches the cursor at 60 Hz. When it is hugging the rightmost")
        deps.stderr.writeLine("  display's right edge, warps it to the leftmost display's left edge.")
        deps.stderr.writeLine("  Symmetric for the leftmost-left, topmost-top, bottommost-bottom edges.")
        deps.stderr.writeLine("  Works for any number of displays and any arrangement (no virtual")
        deps.stderr.writeLine("  clone required). Generalises across all positive screen setups.")
        deps.stderr.writeLine("")
        deps.stderr.writeLine("WHAT IT DOES NOT")
        deps.stderr.writeLine("  Windows do not cross the wrap. macOS WindowServer's compositor")
        deps.stderr.writeLine("  clamps window frames the same way it clamps the cursor; the wrap")
        deps.stderr.writeLine("  is cursor-only. Making dragged windows cross requires Apple's")
        deps.stderr.writeLine("  DriverKit graphics-driver entitlement (Sidecar uses it; Apple")
        deps.stderr.writeLine("  does not grant it to third-party CLI tools).")
        deps.stderr.writeLine("")
        deps.stderr.writeLine("EXAMPLES")
        deps.stderr.writeLine("  wdm cursor-wrap                  # block until SIGTERM/SIGINT")
        deps.stderr.writeLine("  wdm cursor-wrap --duration-ms 60000   # run for 60 s then exit")
    }

    nonisolated(unsafe) private static var signalHandlerInstalled = false
    nonisolated(unsafe) private static var signalSources: [DispatchSourceSignal] = []

    private static func installSignalHandlers(onStop: @escaping () -> Void) {
        guard !signalHandlerInstalled else { return }
        signalHandlerInstalled = true
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)
        signal(SIGHUP, SIG_IGN)
        for sig in [SIGINT, SIGTERM, SIGHUP] as [Int32] {
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { onStop() }
            src.resume()
            signalSources.append(src)
        }
    }
}

/// Thin runner around the pure CyclicArrangementWarper logic that polls
/// real CGEvent locations and posts CGWarpMouseCursorPosition. Lives in
/// CLI rather than WDMSystem so the system module can stay free of the
/// long-running thread lifecycle. Reuses the proven 3-consecutive-samples
/// stuck-detection from VirtualCursorEdgeWarper.
final class CyclicArrangementWarperRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var stopRequested = false

    func stop() {
        lock.withLock { stopRequested = true }
    }

    func run(durationMs: Int?) throws {
        let intervalMs: Int = 16          // 60 Hz
        let consecutive = 3
        let jitterPx: CGFloat = 6
        let deadline: Date? = durationMs.map { Date(timeIntervalSinceNow: TimeInterval($0) / 1000) }

        var atEdgeCount = 0
        var lastLoc: CGPoint = .zero

        while !lock.withLock({ stopRequested }) {
            if let deadline, Date() >= deadline { break }
            let loc = CGEvent(source: nil)?.location ?? .zero
            let displays = activeDisplays()
            let target = CyclicArrangementWarper.cyclicWarpTarget(
                displays: displays, location: loc
            )
            let jitter = abs(loc.x - lastLoc.x) <= jitterPx
                && abs(loc.y - lastLoc.y) <= jitterPx
            if let t = target, jitter {
                atEdgeCount += 1
                if atEdgeCount >= consecutive {
                    CGWarpMouseCursorPosition(t)
                    atEdgeCount = 0
                }
            } else {
                atEdgeCount = 0
            }
            lastLoc = loc
            Thread.sleep(forTimeInterval: TimeInterval(intervalMs) / 1000)
        }
    }

    private func activeDisplays() -> [CyclicArrangementWarper.Display] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map {
            CyclicArrangementWarper.Display(id: $0, bounds: CGDisplayBounds($0))
        }
    }
}
