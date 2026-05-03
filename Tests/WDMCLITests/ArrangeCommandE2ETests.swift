import Foundation
import Testing

@Suite("wdm arrange (e2e)")
struct ArrangeCommandE2ETests {
    @Test("arrange list --json prints one entry per display with origin + rotation")
    func listJSON() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["arrange", "list", "--json"], fixture: fx)
        #expect(r.exitCode == 0)
        let data = Data(r.stdout.utf8)
        let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        #expect(arr?.count == 2)
        #expect((arr?[0]["id"] as? Int) == 1)
    }

    @Test("arrange move applies multiple moves in one safe transaction")
    func moveBulk() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(
            ["arrange", "move", "1", "-1920", "0", "2", "0", "0", "--no-confirm"],
            fixture: fx
        )
        #expect(r.exitCode == 0)
        let after = CLITestHarness.run(["arrange", "list", "--json"], fixture: fx)
        let arr = try JSONSerialization.jsonObject(with: Data(after.stdout.utf8)) as? [[String: Any]]
        let originOf1 = arr?.first { ($0["id"] as? Int) == 1 }?["origin"] as? [String: Int]
        #expect(originOf1?["x"] == -1920)
    }

    @Test("arrange move on unknown display exits 3")
    func unknownExits3() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(
            ["arrange", "move", "999", "0", "0", "--no-confirm"], fixture: fx
        )
        #expect(r.exitCode == 3)
    }
}
