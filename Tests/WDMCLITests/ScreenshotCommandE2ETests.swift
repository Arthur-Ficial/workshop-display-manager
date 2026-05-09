import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm screenshot (e2e, recording shotter)")
struct ScreenshotCommandE2ETests {

    private func makeOutFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-shot-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("out.png")
    }

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-shot-log-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("shot.log")
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

    @Test("screenshot <id> --out <path> records the call and writes a PNG-shaped file")
    func captureBasic() throws {
        let fx = try CLITestHarness.makeFixture()
        let out = try makeOutFile()
        let log = try makeLogFile()
        let r = run(args: ["screenshot", "2", "--out", out.path], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("displayID=2"))
        #expect(body.contains("out=\(out.path)"))
        // Recording shotter writes a 1x1 PNG so e2e checks the path is real.
        let data = try Data(contentsOf: out)
        let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        #expect(Array(data.prefix(8)) == pngHeader)
    }

    @Test("screenshot <id> with no --out exits 2 (usage)")
    func missingOut() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["screenshot", "2"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("screenshot on unknown display exits 3")
    func unknownDisplay() throws {
        let fx = try CLITestHarness.makeFixture()
        let out = try makeOutFile()
        let log = try makeLogFile()
        let r = run(args: ["screenshot", "999", "--out", out.path], fixture: fx, log: log)
        #expect(r.exitCode == 3)
    }

    @Test("screenshot main resolves to the main display's id")
    func mainAlias() throws {
        let fx = try CLITestHarness.makeFixture()
        let out = try makeOutFile()
        let log = try makeLogFile()
        let r = run(args: ["screenshot", "main", "--out", out.path], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("displayID=1"))  // main is id 1 in the harness fixture
    }
}
