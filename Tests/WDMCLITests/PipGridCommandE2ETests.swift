import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm pip-grid (e2e, recording flipper)")
struct PipGridCommandE2ETests {

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-pip-grid-\(UUID().uuidString)")
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

    @Test("pip-grid <id1,id2> --on <dst> --duration-ms <N> records two PIPs at distinct positions")
    func twoSources() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["pip-grid", "1,2", "--on", "1", "--cols", "2", "--duration-ms", "30"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        let runLines = body.split(separator: "\n").filter { $0.hasPrefix("run ") }
        #expect(runLines.count == 2)
        // Each call should record source=1 or source=2 with destination=1.
        let allText = body
        #expect(allText.contains("source=1"))
        #expect(allText.contains("source=2"))
        #expect(allText.contains("destination=1"))
        // Distinct positions (the recording flipper logs `position=<x>,<y>|centered`).
        let positions = runLines.compactMap { line -> String? in
            guard let r = line.range(of: "position=") else { return nil }
            return String(line[r.upperBound...].split(separator: " ").first ?? "")
        }
        #expect(Set(positions).count == positions.count, "positions should be distinct, got \(positions)")
    }

    @Test("pip-grid with no source list exits 2")
    func missing() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["pip-grid"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("pip-grid with unknown id exits 3")
    func unknownID() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["pip-grid", "1,999", "--duration-ms", "30"], fixture: fx, log: log)
        #expect(r.exitCode == 3)
    }

    @Test("pip-grid surfaces PIP task failures")
    func pipTaskFailure() throws {
        let fx = try CLITestHarness.makeFixture()
        let badLog = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-pip-grid-bad-log-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: badLog, withIntermediateDirectories: true)
        let r = run(
            args: ["pip-grid", "1,2", "--on", "1", "--duration-ms", "30"],
            fixture: fx, log: badLog
        )
        #expect(r.exitCode == ExitCodes.ioError)
        #expect(r.stderr.contains("pip-grid: PIP failed"))
    }
}
