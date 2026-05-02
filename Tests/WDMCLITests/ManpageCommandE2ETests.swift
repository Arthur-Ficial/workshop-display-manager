import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm manpage (e2e)")
struct ManpageCommandE2ETests {

    @Test("emits a valid groff section-1 man page")
    func emits() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["manpage"], fixture: fx)
        #expect(r.exitCode == 0)
        #expect(r.stdout.hasPrefix(".TH WDM 1"))
        #expect(r.stdout.contains(".SH NAME"))
        #expect(r.stdout.contains(".SH SYNOPSIS"))
        #expect(r.stdout.contains(".SH DESCRIPTION"))
        #expect(r.stdout.contains(".SH COMMANDS"))
        #expect(r.stdout.contains("list"))
        #expect(r.stdout.contains("switch"))
        #expect(r.stdout.contains("brightness"))
    }

    @Test("includes EXIT CODES section")
    func exitCodes() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["manpage"], fixture: fx)
        #expect(r.stdout.contains(".SH \"EXIT CODES\""))
        #expect(r.stdout.contains("display not found"))
    }
}
