import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI
@testable import WDMSystem

@Suite("wdm screen-windows (e2e, recording lister)")
struct ScreenWindowsCommandE2ETests {

    private func run(args: [String]) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": (try? CLITestHarness.makeFixture().path) ?? "",
            "WDM_TEST_WINDOW_LISTER": "1",
        ]
        let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("screen-windows <id> prints two TestApp/OtherApp rows")
    func basic() throws {
        let r = run(args: ["screen-windows", "2"])
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("TestApp"))
        #expect(r.stdout.contains("OtherApp"))
    }

    @Test("screen-windows <id> --json emits a parseable array")
    func json() throws {
        let r = run(args: ["screen-windows", "main", "--json"])
        #expect(r.exitCode == 0)
        let data = Data(r.stdout.utf8)
        let arr = try JSONDecoder().decode([WindowInfo].self, from: data)
        #expect(arr.count == 2)
    }

    @Test("screen-windows with no args exits 2")
    func noArgs() throws {
        let r = run(args: ["screen-windows"])
        #expect(r.exitCode == 2)
    }

    @Test("screen-windows on unknown display exits 3")
    func unknown() throws {
        let r = run(args: ["screen-windows", "999"])
        #expect(r.exitCode == 3)
    }
}
