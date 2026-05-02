import Testing
import Foundation
@testable import WDMCLI

@Suite("--confirm flag routes to native confirmer")
struct NativeConfirmFlagTests {

    private func run(_ args: [String], fixture: URL, native: String) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_NATIVE_CONFIRMER_STUB": native,   // "yes" or "no"
        ]
        let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("--confirm + native stub returning 'no' reverts the mutation")
    func confirmFlagRevertsOnNo() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = run(["switch", "--confirm"], fixture: fx, native: "no")
        #expect(result.exitCode == 5, "exit 5 = cancelled / reverted")
        // Main display must be restored to its original value (1).
        let after = run(["get", "main", "id"], fixture: fx, native: "no")
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }

    @Test("--confirm + native stub returning 'yes' keeps the mutation")
    func confirmFlagKeepsOnYes() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = run(["switch", "--confirm"], fixture: fx, native: "yes")
        #expect(result.exitCode == 0)
        let after = run(["get", "main", "id"], fixture: fx, native: "yes")
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "2")
    }

    @Test("--no-confirm wins over --confirm (no prompt at all)")
    func noConfirmWins() throws {
        let fx = try CLITestHarness.makeFixture()
        // native stub set to 'no' would revert if it ran.
        let result = run(["switch", "--confirm", "--no-confirm"], fixture: fx, native: "no")
        #expect(result.exitCode == 0)
        let after = run(["get", "main", "id"], fixture: fx, native: "no")
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "2",
                "switch must apply because --no-confirm bypasses any confirmer")
    }
}
