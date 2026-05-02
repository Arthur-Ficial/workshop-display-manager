import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm sleep (e2e, recording sleeper)")
struct SleepCommandE2ETests {

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-sleep-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sleep.log")
    }

    private func run(args: [String], log: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": (try? CLITestHarness.makeFixture().path) ?? "",
            "WDM_TEST_SLEEP_LOG": log.path,
        ]
        let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("wdm sleep invokes the sleeper exactly once and exits 0")
    func sleepInvokesSleeperOnce() throws {
        let log = try makeLogFile()
        let r = run(args: ["sleep"], log: log)
        #expect(r.exitCode == 0)
        let body = (try? String(contentsOf: log)) ?? ""
        #expect(body == "sleepNow\n")
        #expect(r.stderr.contains("AppleHPM") || r.stderr.contains("issue #1"))
    }

    @Test("wdm sleep called twice records two invocations")
    func sleepCalledTwice() throws {
        let log = try makeLogFile()
        _ = run(args: ["sleep"], log: log)
        let r = run(args: ["sleep"], log: log)
        #expect(r.exitCode == 0)
        let body = (try? String(contentsOf: log)) ?? ""
        #expect(body == "sleepNow\nsleepNow\n")
    }
}
