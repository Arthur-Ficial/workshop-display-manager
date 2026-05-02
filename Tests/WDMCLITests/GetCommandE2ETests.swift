import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm get (e2e)")
struct GetCommandE2ETests {

    @Test("get <id> name prints just the name")
    func getName() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = CLITestHarness.run(["get", "1", "name"], fixture: fx)
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "Built-in")
    }

    @Test("get main name resolves the main alias")
    func getMainAlias() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = CLITestHarness.run(["get", "main", "name"], fixture: fx)
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "Built-in")
    }

    @Test("get <id> mode prints the current mode")
    func getMode() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = CLITestHarness.run(["get", "2", "mode"], fixture: fx)
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1920x1080@60")
    }

    @Test("unknown display exits 3 with stderr message")
    func unknownDisplayExit3() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = CLITestHarness.run(["get", "999", "name"], fixture: fx)
        #expect(result.exitCode == 3)
        #expect(result.stderr.contains("999"))
    }

    @Test("--json prints the full DisplayInfo as JSON")
    func getJSON() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = CLITestHarness.run(["get", "1", "--json"], fixture: fx)
        #expect(result.exitCode == 0)
        let data = Data(result.stdout.utf8)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["name"] as? String == "Built-in")
        #expect(parsed?["isMain"] as? Bool == true)
    }
}
