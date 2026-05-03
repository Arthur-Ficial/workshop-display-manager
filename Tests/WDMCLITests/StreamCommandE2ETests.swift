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

    // MARK: - core happy/sad paths

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

    // MARK: - configurable options (TDD)

    @Test("default options: 30fps / 2-sec segments / cursor on")
    func defaultOptions() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "2", "--hls", "/tmp/x", "--duration", "3"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("framerate=30"))
        #expect(body.contains("segmentDurationSec=2"))
        #expect(body.contains("showCursor=true"))
    }

    @Test("--segment-duration 5 propagates")
    func segmentDuration() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "2", "--hls", "/tmp/x", "--duration", "10",
                   "--segment-duration", "5"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("segmentDurationSec=5"))
    }

    @Test("--framerate 60 propagates")
    func framerate() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "2", "--hls", "/tmp/x", "--duration", "5",
                   "--framerate", "60"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("framerate=60"))
    }

    @Test("--no-cursor flips showCursor")
    func noCursor() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "2", "--hls", "/tmp/x", "--duration", "5", "--no-cursor"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("showCursor=false"))
    }

    @Test("--bitrate 8000 propagates as kbps")
    func bitrate() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "2", "--hls", "/tmp/x", "--duration", "5",
                   "--bitrate", "8000"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("bitrateKbps=8000"))
    }

    // MARK: - UNIX-style output (stdout = data, stderr = humans)

    @Test("--json prints structured status to stdout, stderr stays human")
    func jsonOutput() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "2", "--hls", "/tmp/x", "--duration", "3", "--json"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        // stdout is one JSON object, parseable.
        let data = r.stdout.data(using: .utf8) ?? Data()
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(obj?["display"] as? Int == 2)
        #expect(obj?["target"] as? String == "/tmp/x")
        #expect(obj?["mode"] as? String == "hls")
        #expect(obj?["duration"] as? Int == 3)
    }

    @Test("--quiet silences the stderr progress lines")
    func quiet() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "2", "--hls", "/tmp/x", "--duration", "3", "--quiet"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        #expect(!r.stderr.contains("streaming"))
        #expect(!r.stderr.contains("complete"))
    }

    @Test("default mode (no flags): stderr has progress, stdout empty")
    func defaultOutputChannels() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "2", "--hls", "/tmp/x", "--duration", "3"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        #expect(r.stdout.isEmpty)
        #expect(r.stderr.contains("streaming"))
    }

    // MARK: - help

    @Test("--help exits 0 with usage")
    func helpFlag() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["stream", "--help"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        #expect(r.stderr.contains("--hls"))
        #expect(r.stderr.contains("--segment-duration"))
        #expect(r.stderr.contains("--framerate"))
    }

    // MARK: - validation

    @Test("--segment-duration 0 exits 2")
    func zeroSegment() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "2", "--hls", "/tmp/x", "--duration", "5",
                   "--segment-duration", "0"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 2)
    }

    @Test("--framerate negative exits 2")
    func negativeFramerate() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["stream", "2", "--hls", "/tmp/x", "--duration", "5",
                   "--framerate", "-30"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 2)
    }
}
