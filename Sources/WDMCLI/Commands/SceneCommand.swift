import Foundation
import WDMKit

/// Multi-display scene orchestrator. Reads `~/.config/wdm/scenes/<name>.json`
/// (a `[SceneEntry]`), spawns one `wdm virtual create` child per entry, and
/// blocks until SIGTERM, then SIGTERMs every child.
public enum SceneCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let name = pos.first, !name.isEmpty else {
            throw WDMError.usage("usage: wdm scene <name> [--dry-run]")
        }
        let store = SceneStore.resolve(env: deps.processEnv)
        let dryRun = args.contains("--dry-run")
        let exec = ProcessInfo.processInfo.arguments.first ?? "/usr/local/bin/wdm"
        var children: [Process] = []
        let outcome = try WDMController.scene.apply(
            name: name, store: store, dryRun: dryRun
        ) { spawnArgs in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: exec)
            proc.arguments = spawnArgs
            try? proc.run()
            children.append(proc)
        }
        for entry in outcome.entries { logEntry(entry, deps: deps) }
        if dryRun { return ExitCodes.success }
        deps.stderr.writeLine("wdm scene: spawned \(children.count) virtual displays. SIGTERM to tear down.")
        blockUntilSignal()
        for child in children { child.terminate() }
        return ExitCodes.success
    }

    private static func logEntry(_ e: SceneEntry, deps: CLIDeps) {
        var line = "\(e.spec.name): \(e.spec.width)x\(e.spec.height)@\(e.spec.refreshHz) hiDPI=\(e.spec.hiDPI)"
        if let wp = e.wallpaper { line += " wallpaper=\(wp)" }
        if let m = e.mirrorOn { line += " mirror-on=\(m)" }
        deps.stdout.writeLine(line)
    }

    private static func blockUntilSignal() {
        let stop = SignalStopFlag()
        let sources = SignalStopFlag.installSignalHandlers { stop.set() }
        defer { _ = sources }
        while !stop.get() {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
    }
}
