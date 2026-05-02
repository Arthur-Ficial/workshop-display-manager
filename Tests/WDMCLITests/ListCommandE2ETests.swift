import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm list (e2e)")
struct ListCommandE2ETests {

    @Test("--json prints valid JSON with all displays")
    func jsonOutput() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = CLITestHarness.run(["list", "--json"], fixture: fx)
        #expect(result.exitCode == 0)
        let data = Data(result.stdout.utf8)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        #expect(parsed?.count == 2)
        let names = parsed?.compactMap { $0["name"] as? String }
        #expect(names == ["Built-in", "Projector"])
    }

    @Test("default human table contains every display name")
    func humanTable() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = CLITestHarness.run(["list"], fixture: fx)
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Built-in"))
        #expect(result.stdout.contains("Projector"))
        #expect(result.stdout.contains("2560x1664@60"))
        #expect(result.stdout.contains("1920x1080@60"))
    }

    @Test("table marks the main display")
    func mainMarker() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = CLITestHarness.run(["list"], fixture: fx)
        let mainLine = result.stdout
            .split(separator: "\n")
            .first { $0.contains("Built-in") } ?? ""
        #expect(mainLine.contains("*"))
    }
}
