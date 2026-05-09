import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm panorama (e2e, recording shotter)")
struct PanoramaCommandE2ETests {

    private func makeOut() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-pano-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pano.png")
    }

    private func makeLog() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-pano-log-\(UUID().uuidString)")
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

    @Test("panorama --out <path> shoots every display + composes a PNG")
    func basic() throws {
        let fx = try CLITestHarness.makeFixture()
        let out = try makeOut()
        let log = try makeLog()
        let r = run(args: ["panorama", "--out", out.path], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        // Recording shotter logs both displays from the harness fixture.
        let body = try String(contentsOf: log)
        #expect(body.contains("displayID=1"))
        #expect(body.contains("displayID=2"))
        // Output PNG exists and starts with the PNG magic bytes.
        let data = try Data(contentsOf: out)
        let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        #expect(Array(data.prefix(8)) == pngHeader)
    }

    @Test("panorama without --out exits 2 (usage)")
    func missingOut() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLog()
        let r = run(args: ["panorama"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }
}
