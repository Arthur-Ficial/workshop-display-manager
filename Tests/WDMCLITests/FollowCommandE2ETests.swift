import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm follow (e2e, recording cursor + PIP)")
struct FollowCommandE2ETests {

    private func makePipLog() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-follow-pip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pip.log")
    }

    private func run(args: [String], pipLog: URL, cursorSeq: String) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": (try? CLITestHarness.makeFixture().path) ?? "",
            "WDM_TEST_PIP_LOG": pipLog.path,
            "WDM_TEST_CURSOR_SEQ": cursorSeq,
        ]
        let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("follow <dst> spawns PIPs as cursor moves between displays")
    func basic() throws {
        let pipLog = try makePipLog()
        // Cursor visits 1, then 2, then 1 again over the duration.
        // dst=1, so source=1 entries are skipped; only source=2 gets a PIP.
        let r = run(
            args: ["follow", "1", "--poll-ms", "5", "--duration-ms", "100"],
            pipLog: pipLog, cursorSeq: "1,2,1,2,1,2,1,2"
        )
        #expect(r.exitCode == 0)
        let body = (try? String(contentsOf: pipLog)) ?? ""
        // PIP should have been spawned at least once with source=2 destination=1
        // (the cursor visited display 2 multiple times, each is a re-spawn).
        #expect(body.contains("source=2"))
        #expect(body.contains("destination=1"))
    }

    @Test("follow without dst exits 2 (usage)")
    func noArgs() throws {
        let pipLog = try makePipLog()
        let r = run(args: ["follow"], pipLog: pipLog, cursorSeq: "1")
        #expect(r.exitCode == 2)
    }

    @Test("follow on unknown dst exits 3")
    func unknownDst() throws {
        let pipLog = try makePipLog()
        let r = run(
            args: ["follow", "999", "--duration-ms", "10"],
            pipLog: pipLog, cursorSeq: "1"
        )
        #expect(r.exitCode == 3)
    }
}
