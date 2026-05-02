import Foundation
import WDMCore
import WDMSystem

public enum DaemonCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        if pos.first == "install" {
            return try install(args: args, deps: deps)
        }
        return try watchAndRestore(args: args, deps: deps)
    }

    // MARK: - watch loop

    private static func watchAndRestore(args: [String], deps: CLIDeps) throws -> Int32 {
        guard let url = deps.eventsFileURL else {
            throw CLIError.usage(
                "wdm daemon: real-backend event watching is not yet wired in this version. " +
                "Set WDM_TEST_EVENTS_FILE to a JSONL path for hermetic tests."
            )
        }
        let max = parseFlagInt(args, name: "--max-events")

        let stream = EventStreamFile(url: url, pollIntervalMs: 25)
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
        if let custom = parseFlagString(args, name: "--to") {
            target = URL(fileURLWithPath: custom)
        } else {
            target = LaunchAgentInstaller.defaultPlistURL()
        }
        let exec = parseFlagString(args, name: "--exec") ?? "/usr/local/bin/wdm"
        try LaunchAgentInstaller.write(to: target, executablePath: exec)
        deps.stderr.writeLine("daemon: wrote \(target.path)")
        deps.stderr.writeLine("daemon: load with `launchctl load \(target.path)`")
        return ExitCodes.success
    }

    // MARK: - flag helpers

    private static func parseFlagString(_ args: [String], name: String) -> String? {
        guard let i = args.firstIndex(of: name), args.count > i + 1 else { return nil }
        return args[i + 1]
    }

    private static func parseFlagInt(_ args: [String], name: String) -> Int? {
        parseFlagString(args, name: name).flatMap(Int.init)
    }
}
