import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm stream (e2e, recording streamer)")
struct StreamCommandE2ETests {

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-stream-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stream.log")
    }

    private func run(args: [String], fixture: URL, log: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_STREAM_LOG": log.path,
        ]
        let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("stream <id> --hls <dir> --duration N records the call")
    func hls() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "2", "--hls", "/tmp/x", "--duration", "3"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("displayID=2"))
        #expect(body.contains("mode=hls"))
        #expect(body.contains("target=/tmp/x"))
        #expect(body.contains("durationSec=3"))
    }

    @Test("stream <id> --rtmp <url> --duration N records the call")
    func rtmp() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "main", "--rtmp", "rtmp://x.example/stream", "--duration", "60"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("displayID=1"))
        #expect(body.contains("mode=rtmp"))
        #expect(body.contains("target=rtmp://x.example/stream"))
    }

    @Test("stream without --duration exits 2")
    func missingDuration() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["stream", "2", "--hls", "/tmp/x"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("stream without target (--hls or --rtmp) exits 2")
    func missingTarget() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["stream", "2", "--duration", "3"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }

    @Test("stream on unknown display exits 3")
    func unknown() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "999", "--hls", "/tmp/x", "--duration", "3"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 3)
    }
}
