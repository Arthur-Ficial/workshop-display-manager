import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm record (e2e, recording recorder)")
struct RecordCommandE2ETests {

    private func makeOutFile(ext: String = "mov") throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-rec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("out.\(ext)")
    }

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-rec-log-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("rec.log")
    }

    private func run(args: [String], fixture: URL, log: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_RECORD_LOG": log.path,
        ]
        let code = CLITestHarness.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("record <id> --out <path> --duration 1 records the call and writes a placeholder file")
    func basicRecord() throws {
        let fx = try CLITestHarness.makeFixture()
        let out = try makeOutFile()
        let log = try makeLogFile()
        let r = run(args: ["record", "2", "--out", out.path, "--duration", "1"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("displayID=2"))
        #expect(body.contains("out=\(out.path)"))
        #expect(body.contains("durationSec=1"))
        #expect(FileManager.default.fileExists(atPath: out.path))
    }

    @Test("record without --out exits 2 (usage)")
    func missingOut() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["record", "2", "--duration", "1"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("record without --duration exits 2 (usage)")
    func missingDuration() throws {
        let fx = try CLITestHarness.makeFixture()
        let out = try makeOutFile()
        let log = try makeLogFile()
        let r = run(args: ["record", "2", "--out", out.path], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("record with non-positive duration exits 2")
    func badDuration() throws {
        let fx = try CLITestHarness.makeFixture()
        let out = try makeOutFile()
        let log = try makeLogFile()
        let r = run(args: ["record", "2", "--out", out.path, "--duration", "0"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("record on unknown display exits 3")
    func unknownDisplay() throws {
        let fx = try CLITestHarness.makeFixture()
        let out = try makeOutFile()
        let log = try makeLogFile()
        let r = run(args: ["record", "999", "--out", out.path, "--duration", "1"], fixture: fx, log: log)
        #expect(r.exitCode == 3)
    }

    @Test("record main resolves to display id 1")
    func mainAlias() throws {
        let fx = try CLITestHarness.makeFixture()
        let out = try makeOutFile()
        let log = try makeLogFile()
        let r = run(args: ["record", "main", "--out", out.path, "--duration", "1"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("displayID=1"))
    }
}
