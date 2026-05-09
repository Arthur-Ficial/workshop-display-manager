import Foundation
import Darwin
@testable import WDMCLI

/// Captures one CLI invocation for assertions.
struct CLIResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

enum CLITestHarness {

    /// Build a fresh fixture file for a single test and return the path.
    static func makeFixture(_ json: String? = nil) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-cli-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        let payload = json ?? defaultFixture
        try payload.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Invoke the actual wdm binary against a fresh fixture backend.
    static func run(_ args: [String], fixture: URL, extraEnv: [String: String] = [:]) -> CLIResult {
        var env: [String: String] = ["WDM_TEST_FIXTURE": fixture.path]
        for (k, v) in extraEnv { env[k] = v }
        return run(args, env: env)
    }

    static func run(
        args: [String],
        env: [String: String],
        stdout: OutputWriter,
        stderr: OutputWriter
    ) -> Int32 {
        let result = run(args, env: env)
        stdout.write(result.stdout)
        stderr.write(result.stderr)
        return result.exitCode
    }

    /// Invoke the actual wdm binary as a subprocess.
    static func run(_ args: [String], env extraEnv: [String: String], timeout: TimeInterval = 30) -> CLIResult {
        processSlots.wait()
        defer { processSlots.signal() }
        do {
            let proc = Process()
            proc.executableURL = try binaryURL()
            proc.arguments = args
            proc.environment = mergedEnv(extraEnv)
            let out = Pipe()
            let err = Pipe()
            proc.standardOutput = out
            proc.standardError = err
            let done = DispatchSemaphore(value: 0)
            proc.terminationHandler = { _ in done.signal() }
            try proc.run()
            let timedOut = wait(proc, done: done, timeout: timeout) == false
            let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if timedOut {
                return CLIResult(exitCode: 124, stdout: stdout, stderr: stderr + "\nerror: wdm timed out")
            }
            return CLIResult(exitCode: proc.terminationStatus, stdout: stdout, stderr: stderr)
        } catch {
            return CLIResult(exitCode: 127, stdout: "", stderr: "error: \(error)\n")
        }
    }

    private static func mergedEnv(_ extraEnv: [String: String]) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        var scoped = extraEnv
        if scoped["HOME"] == nil, let fixture = scoped["WDM_TEST_FIXTURE"], !fixture.isEmpty {
            scoped["HOME"] = URL(fileURLWithPath: fixture).deletingLastPathComponent().path
        }
        for (k, v) in scoped { env[k] = v }
        return env
    }

    private static func wait(_ proc: Process, done: DispatchSemaphore, timeout: TimeInterval) -> Bool {
        if done.wait(timeout: .now() + timeout) == .success { return true }
        proc.terminate()
        if done.wait(timeout: .now() + 1) == .success { return false }
        kill(proc.processIdentifier, SIGKILL)
        _ = done.wait(timeout: .now() + 1)
        return false
    }

    private static func binaryURL() throws -> URL {
        if let path = ProcessInfo.processInfo.environment["WDM_CLI_BINARY"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            root.appendingPathComponent(".build/debug/wdm"),
            root.appendingPathComponent(".build/arm64-apple-macosx/debug/wdm"),
        ]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            return found
        }
        throw NSError(domain: "CLITestHarness", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "wdm binary missing; run `swift build --product wdm` first",
        ])
    }

    private static let processSlots = DispatchSemaphore(value: 4)

    static let defaultFixture = """
    {
      "snapshot": {
        "createdAt": 1700000000,
        "displays": [
          {
            "id": 1, "name": "Built-in", "isMain": true, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 2560, "height": 1664, "refreshHz": 60 },
            "origin": { "x": 0, "y": 0 },
            "rotationDegrees": 0
          },
          {
            "id": 2, "name": "Projector", "isMain": false, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
            "origin": { "x": 2560, "y": 0 },
            "rotationDegrees": 0
          }
        ]
      },
      "availableModes": {
        "1": [
          { "width": 2560, "height": 1664, "refreshHz": 60 },
          { "width": 1920, "height": 1200, "refreshHz": 60 }
        ],
        "2": [
          { "width": 1920, "height": 1080, "refreshHz": 60 },
          { "width": 1280, "height": 720,  "refreshHz": 60 }
        ]
      }
    }
    """
}
