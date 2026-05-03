import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm cursor-wrap (e2e)")
struct CursorWrapE2ETests {

    private func run(args: [String], fixture: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = ["WDM_TEST_FIXTURE": fixture.path]
        let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("cursor-wrap --help exits 0 and explains what the feature does")
    func helpFlag() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = run(args: ["cursor-wrap", "--help"], fixture: fx)
        #expect(r.exitCode == 0)
        // The help must spell out: cyclic wrap, no virtual clone needed, what
        // it does and what it does NOT do (no native window drag across).
        #expect(r.stderr.contains("cursor-wrap"))
        #expect(r.stderr.contains("cyclic"))
        #expect(r.stderr.contains("rightmost"))
        #expect(r.stderr.contains("leftmost"))
        // Honest about the limitation:
        #expect(r.stderr.contains("does not"))
    }

    @Test("cursor-wrap -h is the same as --help")
    func helpDashH() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = run(args: ["cursor-wrap", "-h"], fixture: fx)
        #expect(r.exitCode == 0)
        #expect(r.stderr.contains("cursor-wrap"))
    }

    @Test("cursor-wrap --duration-ms 50 runs the warper, exits 0 cleanly")
    func bounded() throws {
        let fx = try CLITestHarness.makeFixture()
        // Bounded run lets us assert clean exit without leaving a thread alive.
        let r = run(args: ["cursor-wrap", "--duration-ms", "50"], fixture: fx)
        #expect(r.exitCode == 0)
    }

    @Test("cursor-wrap rejects negative --duration-ms")
    func negativeDuration() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = run(args: ["cursor-wrap", "--duration-ms", "-100"], fixture: fx)
        #expect(r.exitCode == 2)
    }
}
