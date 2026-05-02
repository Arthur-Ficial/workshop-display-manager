import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm focus (e2e)")
struct FocusCommandE2ETests {

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-focus-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("log.txt")
    }

    private func run(args: [String], fixture: URL, log: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_WINDOW_MOVER_LOG": log.path,
        ]
        let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("focus <id> records focus call to recording mover")
    func basic() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["focus", "2"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("focus displayID=2"))
    }

    @Test("focus main resolves to display 1")
    func mainAlias() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["focus", "main"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("focus displayID=1"))
    }

    @Test("focus on unknown display exits 3")
    func unknown() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["focus", "999"], fixture: fx, log: log)
        #expect(r.exitCode == 3)
    }

    @Test("focus with no args exits 2 (usage)")
    func noArgs() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["focus"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }
}
