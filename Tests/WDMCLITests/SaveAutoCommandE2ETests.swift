import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm save --auto (e2e)")
struct SaveAutoCommandE2ETests {

    private func tempProfilesDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-save-auto-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func run(_ args: [String], fixture: URL, profilesDir: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_PROFILES_DIR": profilesDir.path,
        ]
        let code = CLITestHarness.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("save --auto writes to profiles/auto/<edid-hash>.json")
    func saveAuto() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()
        let r = run(["save", "--auto"], fixture: fx, profilesDir: pd)
        #expect(r.exitCode == 0)
        let autoDir = pd.appendingPathComponent("auto")
        let entries = try FileManager.default.contentsOfDirectory(atPath: autoDir.path)
        let json = entries.filter { $0.hasSuffix(".json") }
        #expect(json.count == 1)
        // Filename should be 16 lowercase hex chars + .json
        let name = json[0]
        #expect(name.count == 16 + ".json".count)
    }

    @Test("save --auto + save --auto on the same display set is idempotent")
    func idempotent() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()
        _ = run(["save", "--auto"], fixture: fx, profilesDir: pd)
        _ = run(["save", "--auto"], fixture: fx, profilesDir: pd)
        let autoDir = pd.appendingPathComponent("auto")
        let entries = try FileManager.default.contentsOfDirectory(atPath: autoDir.path)
        #expect(entries.filter { $0.hasSuffix(".json") }.count == 1)
    }
}
