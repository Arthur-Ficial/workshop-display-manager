import Foundation
import Darwin
@testable import WDMRemoteControl

/// Shared headed `wdm-mac` instance — reused ACROSS test invocations
/// where possible. On first call:
///   1. If `~/.config/wdm/remote.json` exists and references a live PID,
///      reuse that running wdm-mac (no relaunch).
///   2. Otherwise launch a fresh one via `open -a WDMMac.app --args --remote`.
/// Subsequent calls within the same process return the cached instance.
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

        // 1. Look for an already-running instance written to the stable
        //    test-HOME path used by spawnHeaded.
        let env = try makeHeadedEnv()
        if let state = try? RemoteStateWriter.read(from: env.stateFile),
           kill(state.pid, 0) == 0,
           Self.isPortAlive(port: state.port) {
            let new = HeadedAppInstance(env: env, pid: state.pid, port: state.port)
            instance = new
            return new
        }

        // 2. None alive — spawn fresh into the same stable env.
        _ = try spawnHeaded(env: env)
        let port = try waitForPort(stateFile: env.stateFile)
        let data = try Data(contentsOf: env.stateFile)
        let json = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let pid = pid_t(json["pid"] as? Int ?? 0)
        Thread.sleep(forTimeInterval: 1.0)  // SwiftUI AX tree warm-up
        let new = HeadedAppInstance(env: env, pid: pid, port: port)
        instance = new
        return new
    }

    private static func isPortAlive(port: UInt16) -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/ui/version") else { return false }
        let sem = DispatchSemaphore(value: 0)
        var ok = false
        var req = URLRequest(url: url)
        req.timeoutInterval = 0.5
        URLSession.shared.dataTask(with: req) { _, resp, _ in
            ok = (resp as? HTTPURLResponse)?.statusCode == 200
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 1.0)
        return ok
    }
}
