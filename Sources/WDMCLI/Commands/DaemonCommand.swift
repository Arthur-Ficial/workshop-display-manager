import Foundation
import WDMCore
import WDMSystem

public enum DaemonCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        if args.contains("--help") || args.contains("-h") {
            deps.stderr.writeLine("usage: wdm daemon [--max-events N]")
            deps.stderr.writeLine("       wdm daemon install [--to <path>] [--exec <path>]")
            deps.stderr.writeLine("Listens on display reconfiguration events; on each event,")
            deps.stderr.writeLine("if a saved auto profile (~/.config/wdm/profiles/auto/<hash>.json)")
            deps.stderr.writeLine("matches the new display set, restores it. Stops with --max-events,")
            deps.stderr.writeLine("SIGTERM, or SIGINT.")
            return ExitCodes.success
        }
        let pos = Args.positional(args)
        if pos.first == "install" {
            return try install(args: args, deps: deps)
        }
        return try watchAndRestore(args: args, deps: deps)
    }

    // MARK: - watch loop

    private static func watchAndRestore(args: [String], deps: CLIDeps) throws -> Int32 {
        let max = Args.flagInt(args, name: "--max-events")

        let stream = deps.eventStream
        let auto = AutoProfileStore.resolve(from: deps.profileStore)

        var seen = 0
        let semaphore = DispatchSemaphore(value: 0)
        let task = Task {
            do {
                for try await _ in stream.events {
                    seen += 1
                    do {
                        let snap = try deps.provider.snapshot()
                        if let target = try auto.load(matching: snap.displays) {
                            try ProfileApplier.apply(
                                target: target, using: deps.provider, options: .noConfirm
                            )
                            deps.stderr.writeLine("daemon: restored auto profile for \(snap.displays.count) displays")
                        } else {
                            deps.stderr.writeLine("daemon: no auto profile for current display set")
                        }
                    } catch {
                        deps.stderr.writeLine("daemon: error handling event: \(error)")
                    }
                    if let max, seen >= max { break }
                }
            } catch {
                deps.stderr.writeLine("daemon: stream error: \(error)")
            }
            semaphore.signal()
        }
        semaphore.wait()
        _ = task
        return ExitCodes.success
    }

    // MARK: - install

    private static func install(args: [String], deps: CLIDeps) throws -> Int32 {
        let target: URL
        if let custom = Args.flagString(args, name: "--to") {
            target = URL(fileURLWithPath: custom)
        } else {
            target = LaunchAgentInstaller.defaultPlistURL()
        }
        let exec = Args.flagString(args, name: "--exec") ?? "/usr/local/bin/wdm"
        try LaunchAgentInstaller.write(to: target, executablePath: exec)
        deps.stderr.writeLine("daemon: wrote \(target.path)")
        deps.stderr.writeLine("daemon: load with `launchctl load \(target.path)`")
        return ExitCodes.success
    }

}
