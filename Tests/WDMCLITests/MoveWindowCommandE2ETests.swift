import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm move-window (e2e, recording mover)")
struct MoveWindowCommandE2ETests {

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-mvwin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("mvwin.log")
    }

    private func run(args: [String], fixture: URL, log: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_WINDOW_MOVER_LOG": log.path,
        ]
        let code = CLITestHarness.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("move-window <pattern> --to <id> records the call and exits 0")
    func basic() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["move-window", "Safari", "--to", "2"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("pattern=Safari"))
        #expect(body.contains("displayID=2"))
    }

    @Test("move-window with main alias resolves to display id 1")
    func mainAlias() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["move-window", "Finder", "--to", "main"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("displayID=1"))
    }

    @Test("move-window with no args exits 2 (usage)")
    func noArgs() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["move-window"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("move-window without --to exits 2 (usage)")
    func missingTo() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["move-window", "Safari"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("move-window targeting unknown display exits 3")
    func unknownDisplay() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["move-window", "Safari", "--to", "999"], fixture: fx, log: log)
        #expect(r.exitCode == 3)
    }
}
