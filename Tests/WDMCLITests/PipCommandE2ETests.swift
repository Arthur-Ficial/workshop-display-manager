import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm pip (e2e, recording flipper)")
struct PipCommandE2ETests {

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-pip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pip.log")
    }

    private func run(args: [String], fixture: URL, log: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_PIP_LOG": log.path,
        ]
        let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("pip <src> with defaults records the call (dst=main, size=defaults, flip=none)")
    func pipDefaults() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["pip", "2", "--duration-ms", "50"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let body = (try? String(contentsOf: log)) ?? ""
        #expect(body.contains("source=2"))
        #expect(body.contains("flip=none"))
        // Default destination is the current main display (id=1 in the harness fixture).
        #expect(body.contains("destination=1"))
    }

    @Test("pip <src> --on <dst> --size WxH --flip vertical records all params")
    func pipExplicit() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["pip", "2", "--on", "1", "--size", "1280x720", "--flip", "vertical", "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = (try? String(contentsOf: log)) ?? ""
        #expect(body.contains("source=2"))
        #expect(body.contains("destination=1"))
        #expect(body.contains("size=1280x720"))
        #expect(body.contains("flip=vertical"))
    }

    @Test("pip rejects unknown source display with exit 3")
    func pipUnknownSource() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["pip", "999", "--duration-ms", "50"], fixture: fx, log: log)
        #expect(r.exitCode == 3)
    }

    @Test("pip rejects unknown destination with exit 3")
    func pipUnknownDestination() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["pip", "2", "--on", "999", "--duration-ms", "50"], fixture: fx, log: log)
        #expect(r.exitCode == 3)
    }

    @Test("pip rejects malformed --size with usage exit code")
    func pipBadSize() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["pip", "2", "--size", "huge", "--duration-ms", "50"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("pip rejects unknown --flip axis with usage exit code")
    func pipBadFlip() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["pip", "2", "--flip", "diagonal", "--duration-ms", "50"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("pip with src == dst is allowed (overlay-on-self) and recorded")
    func pipSrcEqualsDst() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["pip", "1", "--on", "1", "--duration-ms", "50"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let body = (try? String(contentsOf: log)) ?? ""
        #expect(body.contains("source=1"))
        #expect(body.contains("destination=1"))
    }
}
