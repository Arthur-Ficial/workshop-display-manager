import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm bind (e2e)")
struct BindCommandE2ETests {

    private func makeStorePath() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-bind-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("keybindings.json")
    }

    private func run(args: [String], file: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": (try? CLITestHarness.makeFixture().path) ?? "",
            "WDM_KEYBINDINGS_FILE": file.path,
        ]
        let code = CLITestHarness.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("bind <chord> <cmd> writes a normalized entry to JSON")
    func bind() throws {
        let file = try makeStorePath()
        let r = run(args: ["bind", "Shift+Cmd+S", "switch"], file: file)
        #expect(r.exitCode == 0)
        let data = try Data(contentsOf: file)
        let kb = try JSONDecoder().decode([Keybinding].self, from: data)
        #expect(kb.count == 1)
        #expect(kb[0].chord == "cmd+shift+s")
        #expect(kb[0].command == "switch")
    }

    @Test("bind with the same chord twice replaces (not duplicates)")
    func upsert() throws {
        let file = try makeStorePath()
        _ = run(args: ["bind", "cmd+1", "switch"], file: file)
        let r = run(args: ["bind", "cmd+1", "cycle"], file: file)
        #expect(r.exitCode == 0)
        let kb = try JSONDecoder().decode([Keybinding].self, from: try Data(contentsOf: file))
        #expect(kb.count == 1)
        #expect(kb[0].command == "cycle")
    }

    @Test("bind defaults installs the 5 default keybindings")
    func defaults() throws {
        let file = try makeStorePath()
        let r = run(args: ["bind", "defaults"], file: file)
        #expect(r.exitCode == 0)
        let kb = try JSONDecoder().decode([Keybinding].self, from: try Data(contentsOf: file))
        #expect(kb.count == 5)
    }

    @Test("bind unbind <chord> removes the binding")
    func unbind() throws {
        let file = try makeStorePath()
        _ = run(args: ["bind", "cmd+ctrl+s", "switch"], file: file)
        let r = run(args: ["bind", "unbind", "cmd+ctrl+s"], file: file)
        #expect(r.exitCode == 0)
        let kb = try JSONDecoder().decode([Keybinding].self, from: try Data(contentsOf: file))
        #expect(kb.isEmpty)
    }

    @Test("bind unbind <unknown chord> exits 6 (not found)")
    func unbindMissing() throws {
        let file = try makeStorePath()
        let r = run(args: ["bind", "unbind", "cmd+ctrl+x"], file: file)
        #expect(r.exitCode == ExitCodes.profileNotFound)
    }

    @Test("bind list prints every binding")
    func list() throws {
        let file = try makeStorePath()
        _ = run(args: ["bind", "defaults"], file: file)
        let r = run(args: ["bind", "list"], file: file)
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("switch"))
        #expect(r.stdout.contains("cycle"))
    }

    @Test("bind with malformed chord exits 2")
    func malformed() throws {
        let file = try makeStorePath()
        let r = run(args: ["bind", "garbage", "switch"], file: file)
        #expect(r.exitCode == 2)
    }
}
