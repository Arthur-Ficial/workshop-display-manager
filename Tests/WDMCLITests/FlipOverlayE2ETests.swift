import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm flip-overlay (e2e, recording flipper)")
struct FlipOverlayE2ETests {

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-overlay-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("overlay.log")
    }

    private func run(args: [String], fixture: URL, log: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_OVERLAY_LOG": log.path,
        ]
        let code = CLITestHarness.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("flip-overlay <id> vertical --duration-ms 50 records the call and exits 0")
    func vertical() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["flip-overlay", "2", "vertical", "--duration-ms", "50"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let lines = try String(contentsOf: log).split(separator: "\n").map(String.init)
        #expect(lines.contains(where: { $0.contains("displayID=2") && $0.contains("flip=vertical") }))
    }

    @Test("flip-overlay short alias <h> records horizontal flip")
    func horizontalAlias() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["flip-overlay", "2", "h", "--duration-ms", "50"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("flip=horizontal"))
    }

    @Test("flip-overlay rejects unknown axis with usage exit code")
    func badAxis() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["flip-overlay", "2", "diagonal", "--duration-ms", "50"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("flip-overlay on unknown display exits 3")
    func unknownDisplay() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["flip-overlay", "999", "vertical", "--duration-ms", "50"], fixture: fx, log: log)
        #expect(r.exitCode == 3)
    }
}
