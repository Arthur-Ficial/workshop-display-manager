import Foundation

/// Looks up running processes by command-line pattern. Real impl shells out
/// to `pgrep -fl`; recording impl returns a fixed list for hermetic tests.
public protocol ProcessLister: Sendable {
    func find(matching pattern: String) -> [(pid: Int32, command: String)]
}

public final class PgrepProcessLister: ProcessLister, @unchecked Sendable {
    public init() {}
    public func find(matching pattern: String) -> [(pid: Int32, command: String)] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-fl", pattern]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                         encoding: .utf8) ?? ""
        return raw.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let pid = Int32(parts[0]) else { return nil }
            return (pid: pid, command: String(parts[1]))
        }
    }
}

public final class RecordingProcessLister: ProcessLister, @unchecked Sendable {
    private let entries: [(pid: Int32, command: String)]
    public init(entries: [(pid: Int32, command: String)]) { self.entries = entries }
    public func find(matching pattern: String) -> [(pid: Int32, command: String)] {
        entries.filter { $0.command.contains(pattern) }
    }
}

/// Sends signals to processes by pid. Real impl uses `kill(2)`; recording
/// impl logs every call for hermetic tests.
public protocol ProcessSignaler: Sendable {
    func terminate(pid: Int32)
}

public final class RealProcessSignaler: ProcessSignaler, @unchecked Sendable {
    public init() {}
    public func terminate(pid: Int32) { kill(pid, SIGTERM) }
}

public final class RecordingProcessSignaler: ProcessSignaler, @unchecked Sendable {
    private let lock = NSLock()
    private var killed: [Int32] = []
    public init() {}
    public func terminate(pid: Int32) { lock.withLock { killed.append(pid) } }
    public func terminated() -> [Int32] { lock.withLock { killed } }
}
