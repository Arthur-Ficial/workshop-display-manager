import Foundation
import WDMCore
import WDMSystem

/// Diagnostics + soft display lifecycle. Single-purpose sub-verbs in true UNIX style.
public enum DoctorCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        switch pos.first {
        case "probe":
            return try probe(args: args, deps: deps)
        case "disconnect":
            return try disconnect(args: args, deps: deps)
        case nil:
            deps.stdout.writeLine("usage: wdm doctor <subcommand>")
            deps.stdout.writeLine("subcommands:")
            deps.stdout.writeLine("  probe [<id>] [--json]              inspect what wdm sees per display")
            deps.stdout.writeLine("  disconnect <id> [--duration-ms N]  soft-disconnect via CGDisplayCapture")
            deps.stdout.writeLine("                                     (release on SIGTERM/SIGINT/SIGHUP or duration)")
            return ExitCodes.success
        default:
            throw CLIError.usage("wdm doctor: unknown subcommand '\(pos[0])'")
        }
    }

    // MARK: - probe

    private static func probe(args: [String], deps: CLIDeps) throws -> Int32 {
        let useJSON = args.contains("--json")
        let snap = try deps.provider.snapshot()

        let pos = Args.positional(args)
        let displays: [DisplayInfo]
        if pos.count >= 2 {
            let id = try DisplayResolver.resolve(pos[1], in: snap)
            guard let d = snap.display(id: id) else {
                throw ProviderError.displayNotFound(id)
            }
            displays = [d]
        } else {
            displays = snap.displays
        }

        if useJSON {
            let payload = displays.map { d -> [String: Any] in
                [
                    "id": Int(d.id),
                    "name": d.name as Any,
                    "isMain": d.isMain,
                    "isOnline": d.isOnline,
                    "mirrorSource": d.mirrorSource.map(Int.init) as Any,
                    "mode": [
                        "width": d.currentMode.width,
                        "height": d.currentMode.height,
                        "refreshHz": d.currentMode.refreshHz,
                    ],
                    "origin": ["x": d.origin.x, "y": d.origin.y],
                    "rotationDegrees": d.rotationDegrees,
                ]
            }
            let data = try JSONSerialization.data(withJSONObject: payload,
                                                  options: [.prettyPrinted, .sortedKeys])
            if let s = String(data: data, encoding: .utf8) { deps.stdout.write(s) }
            return ExitCodes.success
        }

        for d in displays {
            deps.stdout.writeLine("--- display \(d.id) ---")
            deps.stdout.writeLine("  name:     \(d.name ?? "(unnamed)")")
            deps.stdout.writeLine("  online:   \(d.isOnline ? "yes" : "no")")
            deps.stdout.writeLine("  main:     \(d.isMain ? "yes" : "no")")
            deps.stdout.writeLine("  mode:     \(d.currentMode.width)x\(d.currentMode.height)@\(d.currentMode.refreshHz)")
            deps.stdout.writeLine("  origin:   (\(d.origin.x), \(d.origin.y))")
            deps.stdout.writeLine("  rotation: \(d.rotationDegrees)°")
            if let src = d.mirrorSource {
                deps.stdout.writeLine("  mirror:   source=\(src)")
            } else {
                deps.stdout.writeLine("  mirror:   none")
            }
        }
        return ExitCodes.success
    }

    // MARK: - disconnect (soft-disconnect via CGDisplayCapture)

    private static func disconnect(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw CLIError.usage("usage: wdm doctor disconnect <id> [--duration-ms N]")
        }
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(pos[1], in: snap)
        guard snap.display(id: id) != nil else {
            throw ProviderError.displayNotFound(id)
        }
        let durationMs = parseFlagInt(args, name: "--duration-ms")

        try deps.displayCapturer.capture(id)
        defer { try? deps.displayCapturer.release(id) }

        deps.stderr.writeLine(
            "wdm: display \(id) captured (soft-disconnect). " +
            "Release: SIGTERM/SIGINT/SIGHUP, or wait for --duration-ms."
        )

        let stopFlag = AtomicFlag()
        let sources = installSignalHandlers { stopFlag.set() }
        defer { _ = sources }

        if let ms = durationMs {
            let deadline = Date(timeIntervalSinceNow: TimeInterval(ms) / 1000.0)
            while Date() < deadline && !stopFlag.get() {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            }
        } else {
            while !stopFlag.get() {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
            }
        }
        return ExitCodes.success
    }

    private static func parseFlagInt(_ args: [String], name: String) -> Int? {
        guard let i = args.firstIndex(of: name), args.count > i + 1 else { return nil }
        return Int(args[i + 1])
    }

    private static func installSignalHandlers(_ onSignal: @escaping () -> Void) -> [DispatchSourceSignal] {
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

private final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    func set() { lock.withLock { flag = true } }
    func get() -> Bool { lock.withLock { flag } }
}
