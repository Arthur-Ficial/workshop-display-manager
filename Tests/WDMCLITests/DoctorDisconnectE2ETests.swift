import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm doctor disconnect (e2e, recording capturer)")
struct DoctorDisconnectE2ETests {

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-disconnect-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("capture.log")
    }

    private func run(args: [String], fixture: URL, log: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_CAPTURE_LOG": log.path,
        ]
        let code = CLITestHarness.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("doctor disconnect <id> --duration-ms records capture+release in order")
    func captureReleasePair() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["doctor", "disconnect", "2", "--duration-ms", "50"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        let body = (try? String(contentsOf: log)) ?? ""
        let lines = body.split(separator: "\n").map(String.init)
        #expect(lines.first == "capture id=2")
        #expect(lines.last == "release id=2")
        #expect(lines.count == 2)
    }

    @Test("doctor disconnect on unknown display exits 3 and never captures")
    func unknownDisplay() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["doctor", "disconnect", "999", "--duration-ms", "50"], fixture: fx, log: log)
        #expect(r.exitCode == 3)
        let body = (try? String(contentsOf: log)) ?? ""
        #expect(!body.contains("capture"))
    }

    @Test("doctor disconnect requires <id> — usage error otherwise")
    func missingID() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["doctor", "disconnect"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }
}
