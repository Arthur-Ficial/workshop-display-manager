import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm shot-all (e2e, recording shotter)")
struct ShotAllCommandE2ETests {

    private func makeDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-shot-all-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-shot-all-log-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("log.txt")
    }

    private func run(args: [String], fixture: URL, log: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_SCREENSHOT_LOG": log.path,
        ]
        let code = CLITestHarness.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("shot-all --dir <path> writes one PNG per display in the harness fixture (2 displays)")
    func writesAll() throws {
        let fx = try CLITestHarness.makeFixture()
        let dir = try makeDir()
        let log = try makeLogFile()
        let r = run(args: ["shot-all", "--dir", dir.path], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        // Harness fixture has displays 1 and 2.
        let p1 = dir.appendingPathComponent("display-1.png").path
        let p2 = dir.appendingPathComponent("display-2.png").path
        #expect(FileManager.default.fileExists(atPath: p1))
        #expect(FileManager.default.fileExists(atPath: p2))
        // Recording impl logs both calls.
        let body = try String(contentsOf: log)
        #expect(body.contains("displayID=1"))
        #expect(body.contains("displayID=2"))
    }

    @Test("shot-all without --dir exits 2 (usage)")
    func missingDir() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["shot-all"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("shot-all creates the target dir if it doesn't exist")
    func createsDir() throws {
        let fx = try CLITestHarness.makeFixture()
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-shot-all-new-\(UUID().uuidString)")
        let log = try makeLogFile()
        let r = run(args: ["shot-all", "--dir", parent.path], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        #expect(FileManager.default.fileExists(atPath: parent.path))
    }

    @Test("shot-all stdout lists every output path, one per line")
    func listsPaths() throws {
        let fx = try CLITestHarness.makeFixture()
        let dir = try makeDir()
        let log = try makeLogFile()
        let r = run(args: ["shot-all", "--dir", dir.path], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let lines = r.stdout.split(separator: "\n").map(String.init)
        #expect(lines.contains(where: { $0.hasSuffix("display-1.png") }))
        #expect(lines.contains(where: { $0.hasSuffix("display-2.png") }))
    }
}
