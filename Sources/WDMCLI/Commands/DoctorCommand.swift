import Foundation
import WDMKit

/// Diagnostics + soft display lifecycle.
public enum DoctorCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        switch pos.first {
        case "probe":      return try probe(args: args, deps: deps)
        case "disconnect": return try disconnect(args: args, deps: deps)
        case nil:          return printUsage(deps: deps)
        default:           throw WDMError.usage("wdm doctor: unknown subcommand '\(pos[0])'")
        }
    }

    private static func printUsage(deps: CLIDeps) -> Int32 {
        deps.stdout.writeLine("usage: wdm doctor <subcommand>")
        deps.stdout.writeLine("subcommands:")
        deps.stdout.writeLine("  probe [<id>] [--json]              inspect what wdm sees per display")
        deps.stdout.writeLine("  disconnect <id> [--duration-ms N]  soft-disconnect via CGDisplayCapture")
        deps.stdout.writeLine("                                     (release on SIGTERM/SIGINT/SIGHUP or duration)")
        return ExitCodes.success
    }

    private static func probe(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        let alias = pos.count >= 2 ? pos[1] : nil
        let reports = try deps.controller.doctorProbe(alias: alias)
        if args.contains("--json") {
            deps.stdout.write(try JSONFormatter.encode(reports))
        } else {
            for report in reports { writeHumanReport(report, deps: deps) }
        }
        return ExitCodes.success
    }

    private static func writeHumanReport(_ d: WDMController.DoctorReport, deps: CLIDeps) {
        deps.stdout.writeLine("--- display \(d.displayID) ---")
        deps.stdout.writeLine("  name:     \(d.name ?? "(unnamed)")")
        deps.stdout.writeLine("  online:   \(d.isOnline ? "yes" : "no")")
        deps.stdout.writeLine("  main:     \(d.isMain ? "yes" : "no")")
        deps.stdout.writeLine("  mode:     \(d.mode.width)x\(d.mode.height)@\(d.mode.refreshHz)")
        deps.stdout.writeLine("  origin:   (\(d.origin.x), \(d.origin.y))")
        deps.stdout.writeLine("  rotation: \(d.rotationDegrees)°")
        if let src = d.mirrorSource {
            deps.stdout.writeLine("  mirror:   source=\(src)")
        } else {
            deps.stdout.writeLine("  mirror:   none")
        }
    }

    private static func disconnect(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw WDMError.usage("usage: wdm doctor disconnect <id> [--duration-ms N]")
        }
        let plan = WDMController.DoctorDisconnectPlan(
            alias: pos[1], durationMs: Args.flagInt(args, name: "--duration-ms")
        )
        deps.stderr.writeLine(
            "wdm: display \(pos[1]) captured (soft-disconnect). " +
            "Release: SIGTERM/SIGINT/SIGHUP, or wait for --duration-ms."
        )
        let stopFlag = SignalStopFlag()
        let sources = SignalStopFlag.installSignalHandlers { stopFlag.set() }
        defer { _ = sources }
        try deps.controller.doctorDisconnect(
            plan: plan, using: deps.displayCapturer, shouldStop: { stopFlag.get() }
        )
        return ExitCodes.success
    }
}

/// Shared signal-handler helper for blocking commands.
final class SignalStopFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    func set() { lock.withLock { flag = true } }
    func get() -> Bool { lock.withLock { flag } }

    static func installSignalHandlers(_ onSignal: @escaping () -> Void) -> [DispatchSourceSignal] {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)
        signal(SIGHUP, SIG_IGN)
        return [SIGINT, SIGTERM, SIGHUP].map { sig in
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { onSignal() }
            src.resume()
            return src
        }
    }
}
