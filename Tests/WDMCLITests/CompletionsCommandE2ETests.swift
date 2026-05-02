import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm completions (e2e)")
struct CompletionsCommandE2ETests {

    @Test("completions zsh emits a valid #compdef script")
    func zsh() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["completions", "zsh"], fixture: fx)
        #expect(r.exitCode == 0)
        #expect(r.stdout.hasPrefix("#compdef wdm"))
        #expect(r.stdout.contains("_wdm"))
        #expect(r.stdout.contains("list"))
        #expect(r.stdout.contains("switch"))
        #expect(r.stdout.contains("brightness"))
    }

    @Test("completions bash emits a valid bash completion")
    func bash() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["completions", "bash"], fixture: fx)
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("complete -F _wdm wdm"))
        #expect(r.stdout.contains("_wdm()"))
    }

    @Test("completions fish emits a valid fish completion")
    func fish() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["completions", "fish"], fixture: fx)
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("complete -c wdm"))
        #expect(r.stdout.contains("-a 'list"))
    }

    @Test("completions with no shell exits 2")
    func missingShell() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["completions"], fixture: fx)
        #expect(r.exitCode == 2)
    }

    @Test("completions with unknown shell exits 2")
    func unknownShell() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["completions", "powershell"], fixture: fx)
        #expect(r.exitCode == 2)
    }
}
