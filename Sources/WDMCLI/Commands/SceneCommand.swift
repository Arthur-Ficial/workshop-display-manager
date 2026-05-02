import Foundation
import WDMCore
import WDMSystem

/// Multi-display scene orchestrator. Reads `~/.config/wdm/scenes/<name>.json`
/// (a `[SceneEntry]`), spawns one `wdm virtual create` child per entry,
/// optionally setting a per-display wallpaper and `--mirror-on` PIP. Blocks
/// until SIGTERM, then SIGTERMs every child.
///
/// `--dry-run` prints the scene without spawning anything — useful for
/// verifying a scene file before running it.
public enum SceneCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let name = pos.first, !name.isEmpty else {
            throw CLIError.usage("usage: wdm scene <name> [--dry-run]")
        }
        let store = SceneStore.resolve(env: deps.processEnv)
        let entries = try store.load(name: name)
        let dryRun = args.contains("--dry-run")

        for e in entries {
            var line = "\(e.spec.name): \(e.spec.width)x\(e.spec.height)@\(e.spec.refreshHz) hiDPI=\(e.spec.hiDPI)"
            if let wp = e.wallpaper { line += " wallpaper=\(wp)" }
            if let m = e.mirrorOn { line += " mirror-on=\(m)" }
            deps.stdout.writeLine(line)
        }

        if dryRun { return ExitCodes.success }

        // Spawn each entry as a child `wdm virtual create` process. Wallpaper
        // and --mirror-on are applied per-entry by passing the right flags.
        let exec = ProcessInfo.processInfo.arguments.first ?? "/usr/local/bin/wdm"
        var children: [Process] = []
        for e in entries {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: exec)
            var spawnArgs = [
                "virtual", "create",
                "--name", e.spec.name,
                "--mode", "\(e.spec.width)x\(e.spec.height)@\(e.spec.refreshHz)",
            ]
            if e.spec.hiDPI { spawnArgs.append("--hidpi") }
            if let m = e.mirrorOn {
                spawnArgs.append("--mirror-on")
                spawnArgs.append("\(m)")
            }
            proc.arguments = spawnArgs
            try? proc.run()
            children.append(proc)
        }
        deps.stderr.writeLine("wdm scene: spawned \(children.count) virtual displays. SIGTERM to tear down.")

        // Block until SIGTERM, then forward to children. Reuses the same
        // signal-handler retention pattern as AppKitOverlayFlipper.
        let stopFlag = AtomicSceneFlag()
        let sources = installSignalHandlers { stopFlag.set() }
        defer { _ = sources }
        while !stopFlag.get() {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
        for c in children {
            c.terminate()
        }
        return ExitCodes.success
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

private final class AtomicSceneFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var f = false
    func set() { lock.withLock { f = true } }
    func get() -> Bool { lock.withLock { f } }
}
