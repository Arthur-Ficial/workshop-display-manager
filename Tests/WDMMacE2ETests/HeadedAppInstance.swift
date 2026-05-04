import Foundation
import Darwin

/// Shared headed `wdm-mac` instance. First test to ask spawns it; every
/// subsequent test reuses the same process + port. The wdm-mac PID is
/// pulled from the state file (the `/usr/bin/open` proxy exits quickly,
/// so we can't track via Process.isRunning).
@MainActor
final class HeadedAppInstance {
    private static var instance: HeadedAppInstance?
    private static let lock = NSLock()

    let env: HeadedEnv
    let pid: pid_t
    let port: UInt16

    private init(env: HeadedEnv, pid: pid_t, port: UInt16) {
        self.env = env; self.pid = pid; self.port = port
    }

    private var isRunning: Bool { kill(pid, 0) == 0 }

    static func shared() throws -> HeadedAppInstance {
        lock.lock(); defer { lock.unlock() }
        if let inst = instance, inst.isRunning { return inst }
        let env = try makeHeadedEnv()
        _ = try spawnHeaded(env: env)  // proxy proc — exits immediately
        let port = try waitForPort(stateFile: env.stateFile)
        // Read the wdm-mac pid from the state file.
        let data = try Data(contentsOf: env.stateFile)
        let json = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let pid = pid_t(json["pid"] as? Int ?? 0)
        // Give SwiftUI a beat to populate its AX tree.
        Thread.sleep(forTimeInterval: 1.0)
        let new = HeadedAppInstance(env: env, pid: pid, port: port)
        instance = new
        return new
    }
}
