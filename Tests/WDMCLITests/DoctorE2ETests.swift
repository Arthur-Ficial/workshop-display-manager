import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm doctor (e2e)")
struct DoctorE2ETests {

    @Test("doctor probe prints a section per display from the fixture")
    func probeAllDisplays() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["doctor", "probe"], fixture: fx)
        #expect(r.exitCode == 0)
        // Built-in (id=1) and Projector (id=2) from the fixture are both reported.
        #expect(r.stdout.contains("display 1"))
        #expect(r.stdout.contains("display 2"))
        // Each section reports the basics: mode + origin + main-flag + rotation.
        #expect(r.stdout.contains("mode:"))
        #expect(r.stdout.contains("origin:"))
        #expect(r.stdout.contains("main:"))
        #expect(r.stdout.contains("rotation:"))
    }

    @Test("doctor probe <id> narrows to a single display")
    func probeOne() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["doctor", "probe", "2"], fixture: fx)
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("display 2"))
        #expect(!r.stdout.contains("display 1"))
    }

    @Test("doctor probe --json emits a parseable array")
    func probeJSON() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["doctor", "probe", "--json"], fixture: fx)
        #expect(r.exitCode == 0)
        let data = Data(r.stdout.utf8)
        let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        #expect(arr?.count == 2)
        #expect((arr?[0]["id"] as? Int) != nil)
        #expect((arr?[0]["mode"] as? [String: Any]) != nil)
    }

    @Test("doctor probe on unknown display exits 3")
    func probeUnknown() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["doctor", "probe", "999"], fixture: fx)
        #expect(r.exitCode == 3)
    }

    @Test("doctor (no subcommand) lists available subcommands and exits 0")
    func doctorHelp() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["doctor"], fixture: fx)
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("probe") || r.stderr.contains("probe"))
    }
}
