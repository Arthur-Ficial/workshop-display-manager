import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm tile-app (e2e, recording mover)")
struct TileAppCommandE2ETests {

    private func makeLog() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-tile-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("log.txt")
    }

    private func run(args: [String], log: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": (try? CLITestHarness.makeFixture().path) ?? "",
            "WDM_TEST_WINDOW_MOVER_LOG": log.path,
        ]
        let code = CLITestHarness.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("tile-app records the pattern + every resolved display id")
    func basic() throws {
        let log = try makeLog()
        let r = run(args: ["tile-app", "Safari", "--across", "1,2"], log: log)
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("pattern=Safari"))
        #expect(body.contains("displayIDs=1,2"))
    }

    @Test("tile-app without --across exits 2")
    func missingAcross() throws {
        let log = try makeLog()
        let r = run(args: ["tile-app", "Safari"], log: log)
        #expect(r.exitCode == 2)
    }

    @Test("tile-app on unknown id exits 3")
    func unknownID() throws {
        let log = try makeLog()
        let r = run(args: ["tile-app", "Safari", "--across", "1,999"], log: log)
        #expect(r.exitCode == 3)
    }
}
