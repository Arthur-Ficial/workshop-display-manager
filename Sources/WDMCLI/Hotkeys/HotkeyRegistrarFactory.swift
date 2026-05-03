import Foundation
import WDMSystem

/// Picks the right `HotkeyRegistrar` based on environment. Tests set
/// `WDM_TEST_HOTKEYS_LOG` to swap in the hermetic recording impl.
public enum HotkeyRegistrarFactory {
    public static func make(env: [String: String]) -> HotkeyRegistrar {
        if let logPath = env["WDM_TEST_HOTKEYS_LOG"] {
            let fire = (env["WDM_TEST_HOTKEYS_FIRE"] ?? "")
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return RecordingHotkeyRegistrar(
                logURL: URL(fileURLWithPath: logPath),
                fireChords: fire
            )
        }
        return CarbonHotkeyRegistrar()
    }
}

/// Dispatches a fired chord to its bound `wdm` invocation. In tests,
/// writes to `WDM_TEST_HOTKEYS_DISPATCH_LOG` so the e2e suite can assert
/// the right command was invoked without spawning a real subprocess.
/// In production, spawns `/usr/local/bin/wdm <args>` so a misbehaving
/// command can never crash the listener daemon.
public enum HotkeyDispatcherFactory {
    public static func make(env: [String: String]) -> (String) -> Void {
        if let dispatchLog = env["WDM_TEST_HOTKEYS_DISPATCH_LOG"] {
            let url = URL(fileURLWithPath: dispatchLog)
            try? "".write(to: url, atomically: true, encoding: .utf8)
            return { command in
                let line = "dispatch \(command)\n"
                let data = Data(line.utf8)
                if let h = try? FileHandle(forWritingTo: url) {
                    defer { try? h.close() }
                    do {
                        try h.seekToEnd()
                        try h.write(contentsOf: data)
                    } catch {
                        try? line.write(to: url, atomically: true, encoding: .utf8)
                    }
                }
            }
        }
        let exec = env["WDM_HOTKEYS_EXEC"] ?? "/usr/local/bin/wdm"
        return { command in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: exec)
            proc.arguments = command.split(separator: " ").map(String.init)
            // Best-effort fire-and-forget — the daemon must not block on a
            // long-running bound command, and a crash in the bound command
            // must not take the listener down.
            try? proc.run()
        }
    }
}
