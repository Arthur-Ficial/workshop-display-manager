import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm hotkeys (e2e)")
struct HotkeysCommandE2ETests {

    private static func setupKeybindingsFile() throws -> (URL, [String: String]) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-hk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let kbFile = dir.appendingPathComponent("keybindings.json")
        let agentDir = dir.appendingPathComponent("LaunchAgents")
        try FileManager.default.createDirectory(at: agentDir, withIntermediateDirectories: true)
        let env: [String: String] = [
            "WDM_KEYBINDINGS_FILE": kbFile.path,
            "WDM_LAUNCHAGENTS_DIR": agentDir.path,
        ]
        return (dir, env)
    }

    private static func runWithEnv(_ args: [String], env: [String: String], fixture: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        var combined = env
        combined["WDM_TEST_FIXTURE"] = fixture.path
        let exitCode = CLIRunner.run(args: args, env: combined, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: exitCode, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("hotkeys list shows current bindings (initially empty)")
    func listEmpty() throws {
        let fx = try CLITestHarness.makeFixture()
        let (_, env) = try Self.setupKeybindingsFile()
        let r = Self.runWithEnv(["hotkeys", "list"], env: env, fixture: fx)
        #expect(r.exitCode == 0)
        #expect(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("hotkeys set <chord> <command> adds a binding")
    func setBinding() throws {
        let fx = try CLITestHarness.makeFixture()
        let (_, env) = try Self.setupKeybindingsFile()
        let r1 = Self.runWithEnv(["hotkeys", "set", "cmd+ctrl+shift+s", "switch"], env: env, fixture: fx)
        #expect(r1.exitCode == 0)
        let r2 = Self.runWithEnv(["hotkeys", "list"], env: env, fixture: fx)
        #expect(r2.stdout.contains("cmd+ctrl+shift+s"))
        #expect(r2.stdout.contains("switch"))
    }

    @Test("hotkeys delete <chord> removes a binding; missing exits 6")
    func deleteBinding() throws {
        let fx = try CLITestHarness.makeFixture()
        let (_, env) = try Self.setupKeybindingsFile()
        _ = Self.runWithEnv(["hotkeys", "set", "cmd+ctrl+shift+s", "switch"], env: env, fixture: fx)
        let r1 = Self.runWithEnv(["hotkeys", "delete", "cmd+ctrl+shift+s"], env: env, fixture: fx)
        #expect(r1.exitCode == 0)
        let r2 = Self.runWithEnv(["hotkeys", "list"], env: env, fixture: fx)
        #expect(r2.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let r3 = Self.runWithEnv(["hotkeys", "delete", "cmd+ctrl+shift+s"], env: env, fixture: fx)
        #expect(r3.exitCode == 6)
    }

    @Test("hotkeys reset installs the default binding set")
    func resetDefaults() throws {
        let fx = try CLITestHarness.makeFixture()
        let (_, env) = try Self.setupKeybindingsFile()
        let r = Self.runWithEnv(["hotkeys", "reset"], env: env, fixture: fx)
        #expect(r.exitCode == 0)
        let listed = Self.runWithEnv(["hotkeys", "list"], env: env, fixture: fx)
        #expect(listed.stdout.contains("cmd+ctrl+shift+s"))
        #expect(listed.stdout.contains("switch"))
        #expect(listed.stdout.contains("cmd+ctrl+shift+c"))
    }

    @Test("hotkeys daemon --max-events 0 registers every saved chord with the registrar")
    func daemonRegistersChords() throws {
        let fx = try CLITestHarness.makeFixture()
        let (dir, baseEnv) = try Self.setupKeybindingsFile()
        var env = baseEnv
        let regLog = dir.appendingPathComponent("registrations.log")
        env["WDM_TEST_HOTKEYS_LOG"] = regLog.path
        // Seed two bindings.
        _ = Self.runWithEnv(["hotkeys", "set", "cmd+ctrl+shift+s", "switch"], env: env, fixture: fx)
        _ = Self.runWithEnv(["hotkeys", "set", "cmd+ctrl+shift+c", "cycle"], env: env, fixture: fx)
        let r = Self.runWithEnv(
            ["hotkeys", "daemon", "--max-events", "0"], env: env, fixture: fx
        )
        #expect(r.exitCode == 0)
        let log = (try? String(contentsOf: regLog, encoding: .utf8)) ?? ""
        #expect(log.contains("register cmd+ctrl+shift+s"))
        #expect(log.contains("register cmd+ctrl+shift+c"))
    }

    @Test("hotkeys daemon dispatches the bound command when the chord fires")
    func daemonDispatchesOnFire() throws {
        let fx = try CLITestHarness.makeFixture()
        let (dir, baseEnv) = try Self.setupKeybindingsFile()
        var env = baseEnv
        let regLog = dir.appendingPathComponent("registrations.log")
        let dispatchLog = dir.appendingPathComponent("dispatch.log")
        env["WDM_TEST_HOTKEYS_LOG"] = regLog.path
        env["WDM_TEST_HOTKEYS_DISPATCH_LOG"] = dispatchLog.path
        // Pre-load a single "fire this chord" instruction for the recording registrar.
        env["WDM_TEST_HOTKEYS_FIRE"] = "cmd+ctrl+shift+s"
        _ = Self.runWithEnv(["hotkeys", "set", "cmd+ctrl+shift+s", "switch"], env: env, fixture: fx)
        let r = Self.runWithEnv(
            ["hotkeys", "daemon", "--max-events", "1"], env: env, fixture: fx
        )
        #expect(r.exitCode == 0)
        let dispatch = (try? String(contentsOf: dispatchLog, encoding: .utf8)) ?? ""
        #expect(dispatch.contains("dispatch switch"))
    }

    @Test("hotkeys install writes a LaunchAgent plist; uninstall removes it")
    func installAndUninstall() throws {
        let fx = try CLITestHarness.makeFixture()
        let (dir, env) = try Self.setupKeybindingsFile()
        let plistPath = dir
            .appendingPathComponent("LaunchAgents")
            .appendingPathComponent("com.fullstackoptimization.wdm.hotkeys.plist")
        let r1 = Self.runWithEnv(["hotkeys", "install"], env: env, fixture: fx)
        #expect(r1.exitCode == 0)
        #expect(FileManager.default.fileExists(atPath: plistPath.path))
        let body = try String(contentsOf: plistPath, encoding: .utf8)
        #expect(body.contains("hotkeys"))
        #expect(body.contains("daemon"))
        let r2 = Self.runWithEnv(["hotkeys", "uninstall"], env: env, fixture: fx)
        #expect(r2.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: plistPath.path))
    }

    @Test("hotkeys status reports installed-or-not plus active binding count")
    func status() throws {
        let fx = try CLITestHarness.makeFixture()
        let (_, env) = try Self.setupKeybindingsFile()
        _ = Self.runWithEnv(["hotkeys", "set", "cmd+ctrl+shift+s", "switch"], env: env, fixture: fx)
        let r1 = Self.runWithEnv(["hotkeys", "status"], env: env, fixture: fx)
        #expect(r1.exitCode == 0)
        #expect(r1.stdout.contains("not installed") || r1.stderr.contains("not installed"))
        #expect(r1.stdout.contains("1 binding") || r1.stderr.contains("1 binding"))
        _ = Self.runWithEnv(["hotkeys", "install"], env: env, fixture: fx)
        let r2 = Self.runWithEnv(["hotkeys", "status"], env: env, fixture: fx)
        #expect(r2.stdout.contains("installed") || r2.stderr.contains("installed"))
    }
}
