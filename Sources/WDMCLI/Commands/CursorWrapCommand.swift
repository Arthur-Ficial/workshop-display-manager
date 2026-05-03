import Foundation
import WDMKit

/// `wdm cursor-wrap` — cyclic cursor wrap across the active arrangement.
public enum CursorWrapCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        if args.contains("--help") || args.contains("-h") {
            printUsage(deps: deps)
            return ExitCodes.success
        }
        let durationMs = try parseDuration(args)

        deps.stderr.writeLine(
            "wdm cursor-wrap: cyclic wrap active. " +
            "Right-edge → leftmost; left-edge → rightmost; " +
            "top → bottom; bottom → top. Cursor only — windows do not cross."
        )

        let stopFlag = SignalStopFlag()
        let sources = SignalStopFlag.installSignalHandlers { stopFlag.set() }
        defer { _ = sources }
        let plan = WDMController.CursorWrapPlan(durationMs: durationMs)
        let io = CursorIOFactory.make(env: deps.processEnv)
        try WDMController.cursorWrap(plan: plan, io: io, shouldStop: { stopFlag.get() })
        deps.stderr.writeLine("wdm cursor-wrap: stopped.")
        return ExitCodes.success
    }

    private static func parseDuration(_ args: [String]) throws -> Int? {
        guard let s = Args.flagString(args, name: "--duration-ms") else { return nil }
        guard let v = Int(s), v > 0 else {
            throw WDMError.usage("cursor-wrap: --duration-ms must be a positive integer (got '\(s)')")
        }
        return v
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
}
