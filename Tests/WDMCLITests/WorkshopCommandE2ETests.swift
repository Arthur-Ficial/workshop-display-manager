import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm workshop (e2e)")
struct WorkshopCommandE2ETests {

    private func tempProfilesDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-workshop-\(UUID().uuidString)")
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

    @Test("start --audience 2 saves current state and switches main")
    func start() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()
        let r = run(["workshop", "start", "--audience", "2", "--no-confirm"],
                    fixture: fx, profilesDir: pd)
        #expect(r.exitCode == 0)
        let path = pd.appendingPathComponent("last-workshop.json")
        #expect(FileManager.default.fileExists(atPath: path.path))
        let after = run(["get", "main", "id"], fixture: fx, profilesDir: pd)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "2")
    }

    @Test("stop restores the saved state")
    func stop() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()
        // 1 starts as main in default fixture; switch to 2 via workshop start
        _ = run(["workshop", "start", "--audience", "2", "--no-confirm"],
                fixture: fx, profilesDir: pd)
        // ... now stop
        let r = run(["workshop", "stop", "--no-confirm"], fixture: fx, profilesDir: pd)
        #expect(r.exitCode == 0)
        let after = run(["get", "main", "id"], fixture: fx, profilesDir: pd)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }

    @Test("start without --audience exits 2 (usage)")
    func missingAudience() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()
        let r = run(["workshop", "start", "--no-confirm"], fixture: fx, profilesDir: pd)
        #expect(r.exitCode == 2)
    }

    @Test("start --audience to unknown display exits 3")
    func unknownAudience() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()
        let r = run(["workshop", "start", "--audience", "99", "--no-confirm"],
                    fixture: fx, profilesDir: pd)
        #expect(r.exitCode == 3)
    }

    @Test("stop without a saved profile exits 6 (profile-not-found)")
    func stopWithoutProfile() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()
        let r = run(["workshop", "stop", "--no-confirm"], fixture: fx, profilesDir: pd)
        #expect(r.exitCode == 6)
    }
}
