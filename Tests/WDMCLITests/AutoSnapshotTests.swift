import Testing
import Foundation
@testable import WDMCLI

@Suite("auto-snapshot to 'last' profile")
struct AutoSnapshotTests {

    private func tempProfilesDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-auto-\(UUID().uuidString)")
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
        let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("any mutation writes pre-state to profile 'last' BEFORE applying")
    func autoSnapshot() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()

        // Mutate: switch main
        let r = run(["switch", "--no-confirm"], fixture: fx, profilesDir: pd)
        #expect(r.exitCode == 0)

        let lastPath = pd.appendingPathComponent("last.json")
        #expect(FileManager.default.fileExists(atPath: lastPath.path),
                "every mutation must write 'last' profile")

        // 'last' must reflect the pre-state, i.e. main was 1.
        let restore = run(["restore", "last", "--no-confirm"], fixture: fx, profilesDir: pd)
        #expect(restore.exitCode == 0)
        let after = run(["get", "main", "id"], fixture: fx, profilesDir: pd)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }

    @Test("read-only commands do NOT write 'last'")
    func readOnlyDoesNotWriteLast() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()

        _ = run(["list"], fixture: fx, profilesDir: pd)
        _ = run(["get", "main"], fixture: fx, profilesDir: pd)
        _ = run(["modes", "1"], fixture: fx, profilesDir: pd)

        let lastPath = pd.appendingPathComponent("last.json")
        #expect(FileManager.default.fileExists(atPath: lastPath.path) == false)
    }
}
