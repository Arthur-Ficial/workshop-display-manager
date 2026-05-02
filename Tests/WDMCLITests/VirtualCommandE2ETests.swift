import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm virtual (e2e, recording manager)")
struct VirtualCommandE2ETests {

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-virt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vd.log")
    }

    private func run(args: [String], fixture: URL, log: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_VIRTUAL_LOG": log.path,
        ]
        let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("virtual create with full args records spec and exits 0")
    func createFull() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create",
                   "--name", "Workshop Demo",
                   "--mode", "1920x1080@60",
                   "--hidpi",
                   "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("name=Workshop Demo"))
        #expect(body.contains("1920x1080@60"))
        #expect(body.contains("hiDPI=true"))
    }

    @Test("virtual create with only --name uses defaults")
    func createDefaults() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create", "--name", "Quick", "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("name=Quick"))
        #expect(body.contains("1920x1080@60"))
        #expect(body.contains("hiDPI=true"))
    }

    @Test("virtual create without --name fails with usage exit code")
    func createMissingName() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create", "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 2)
    }

    @Test("virtual create with malformed --mode fails with usage exit code")
    func createBadMode() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create", "--name", "X", "--mode", "huge", "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 2)
    }

    @Test("virtual remove with no matching process exits 6 (not found)")
    func removeNoMatch() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        // Name doesn't exist as a running `wdm virtual create` process — the
        // implementation pgreps for it and finds nothing.
        let r = run(args: ["virtual", "remove", "definitely-not-running"], fixture: fx, log: log)
        #expect(r.exitCode == ExitCodes.profileNotFound)
    }

    @Test("virtual list prints virtual displays from the fixture (none in default fixture)")
    func listEmpty() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["virtual", "list"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        // The default fixture has no virtual displays; output should be empty
        // (or a header line) — either way, no crash.
    }

    @Test("virtual without subcommand prints usage and exits 0")
    func noSubcommand() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["virtual"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("create"))
        #expect(r.stdout.contains("list"))
        #expect(r.stdout.contains("remove"))
    }

    @Test("virtual with unknown subcommand exits 2")
    func unknownSubcommand() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["virtual", "explode"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }
}
