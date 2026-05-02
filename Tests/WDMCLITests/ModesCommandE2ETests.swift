import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm modes (e2e)")
struct ModesCommandE2ETests {

    @Test("modes <id> lists every available mode, one per line")
    func listsModes() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = CLITestHarness.run(["modes", "2"], fixture: fx)
        #expect(result.exitCode == 0)
        let lines = result.stdout
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        #expect(lines.contains("1920x1080@60"))
        #expect(lines.contains("1280x720@60"))
    }

    @Test("--json lists modes as JSON array of strings")
    func jsonOutput() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = CLITestHarness.run(["modes", "1", "--json"], fixture: fx)
        #expect(result.exitCode == 0)
        let data = Data(result.stdout.utf8)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String]
        #expect(parsed?.contains("2560x1664@60") == true)
    }

    @Test("modes for unknown display exits 3")
    func unknownExit3() throws {
        let fx = try CLITestHarness.makeFixture()
        let result = CLITestHarness.run(["modes", "999"], fixture: fx)
        #expect(result.exitCode == 3)
    }
}
