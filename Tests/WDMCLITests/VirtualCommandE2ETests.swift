import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm virtual (e2e, recording manager)")
struct VirtualCommandE2ETests {

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-virt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vd.log")
    }

    private func run(args: [String], fixture: URL, log: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_VIRTUAL_LOG": log.path,
        ]
        let code = CLITestHarness.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("virtual create with full args records spec and exits 0")
    func createFull() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create",
                   "--name", "Workshop Demo",
                   "--mode", "1920x1080@60",
                   "--hidpi",
                   "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("name=Workshop Demo"))
        #expect(body.contains("1920x1080@60"))
        #expect(body.contains("hiDPI=true"))
    }

    @Test("virtual create --preset iphone-17-pro-max uses the current flagship size")
    func createPresetIPhone17ProMax() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create",
                   "--name", "iPhone 17 Pro Max",
                   "--preset", "iphone-17-pro-max",
                   "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("1320x2868@120"))
        #expect(body.contains("hiDPI=true"))
    }

    @Test("virtual create --preset iphone (alias) resolves to the current flagship")
    func createPresetIPhoneAlias() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create",
                   "--name", "iPhone",
                   "--preset", "iphone",
                   "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        // alias `iphone` → `iphone-17-pro-max` → 1320x2868@120
        #expect(body.contains("1320x2868@120"))
    }

    @Test("virtual create --preset iphone-15-pro still works (legacy)")
    func createPresetIPhone15Pro() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create",
                   "--name", "iPhone 15 Pro",
                   "--preset", "iphone-15-pro",
                   "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("1179x2556@120"))
        #expect(body.contains("hiDPI=true"))
    }

    @Test("virtual create --preset ipad-mini uses iPad mini dimensions")
    func createPresetIPadMini() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create",
                   "--name", "iPad mini",
                   "--preset", "ipad-mini",
                   "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("1488x2266@60"))
    }

    @Test("virtual create --preset unknown exits 2 with helpful error")
    func createPresetUnknown() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create",
                   "--name", "X",
                   "--preset", "nokia-3310",
                   "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 2)
        #expect(r.stderr.contains("preset"))
    }

    @Test("virtual presets lists all known mobile presets")
    func listPresets() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["virtual", "presets"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("iphone-15-pro"))
        #expect(r.stdout.contains("ipad-mini"))
        #expect(r.stdout.contains("1179x2556"))
    }

    @Test("virtual create with only --name uses defaults")
    func createDefaults() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create", "--name", "Quick", "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("name=Quick"))
        #expect(body.contains("1920x1080@60"))
        #expect(body.contains("hiDPI=true"))
    }

    @Test("virtual create without --name fails with usage exit code")
    func createMissingName() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create", "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 2)
    }

    @Test("virtual create with malformed --mode fails with usage exit code")
    func createBadMode() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(
            args: ["virtual", "create", "--name", "X", "--mode", "huge", "--duration-ms", "50"],
            fixture: fx, log: log
        )
        #expect(r.exitCode == 2)
    }

    @Test("virtual create --mirror-on <id> also triggers a PIP for the new virtual")
    func mirrorOnAutoPip() throws {
        let fx = try CLITestHarness.makeFixture()
        let virtLog = try makeLogFile()
        // Separate log dir for the PIP recording impl.
        let pipLogDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-mirror-on-pip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: pipLogDir, withIntermediateDirectories: true)
        let pipLog = pipLogDir.appendingPathComponent("pip.log")

        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fx.path,
            "WDM_TEST_VIRTUAL_LOG": virtLog.path,
            "WDM_TEST_PIP_LOG": pipLog.path,
        ]
        // The harness fixture has display 1 = main, 2 = projector. --mirror-on 1
        // tells the verb to spawn a PIP onto display 1 mirroring the new virtual.
        // The recording PIP uses the *requested* sourceID — for the test it can
        // be any positive id since we're verifying the call was made, not which
        // CG-issued id the virtual got.
        let code = CLITestHarness.run(
            args: ["virtual", "create",
                   "--name", "Auto",
                   "--mode", "1280x720@60",
                   "--mirror-on", "1",
                   "--duration-ms", "50"],
            env: env, stdout: stdout, stderr: stderr
        )
        #expect(code == 0)
        let virtBody = try String(contentsOf: virtLog)
        #expect(virtBody.contains("name=Auto"))
        let pipBody = try String(contentsOf: pipLog)
        #expect(pipBody.contains("destination=1"),
                "expected the PIP to be spawned with --on 1; log was:\n\(pipBody)")
        // The PIP source must reference *some* displayID — the recording impl
        // logs whatever was requested.
        #expect(pipBody.contains("source="))
    }

    @Test("virtual create without --mirror-on does NOT spawn a PIP")
    func noMirrorOnNoPip() throws {
        let fx = try CLITestHarness.makeFixture()
        let virtLog = try makeLogFile()
        let pipLogDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-no-mirror-pip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: pipLogDir, withIntermediateDirectories: true)
        let pipLog = pipLogDir.appendingPathComponent("pip.log")

        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fx.path,
            "WDM_TEST_VIRTUAL_LOG": virtLog.path,
            "WDM_TEST_PIP_LOG": pipLog.path,
        ]
        let code = CLITestHarness.run(
            args: ["virtual", "create", "--name", "NoPip", "--duration-ms", "50"],
            env: env, stdout: stdout, stderr: stderr
        )
        #expect(code == 0)
        // PIP log must not exist — recording impl only writes on first call.
        #expect(!FileManager.default.fileExists(atPath: pipLog.path))
    }

    @Test("virtual remove with no matching process exits 6 (not found)")
    func removeNoMatch() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        // Name doesn't exist as a running `wdm virtual create` process — the
        // implementation pgreps for it and finds nothing.
        let r = run(args: ["virtual", "remove", "definitely-not-running"], fixture: fx, log: log)
        #expect(r.exitCode == ExitCodes.profileNotFound)
    }

    @Test("virtual list prints virtual displays from the fixture (none in default fixture)")
    func listEmpty() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["virtual", "list"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        // The default fixture has no virtual displays; output should be empty
        // (or a header line) — either way, no crash.
    }

    @Test("virtual without subcommand prints usage and exits 0")
    func noSubcommand() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["virtual"], fixture: fx, log: log)
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("create"))
        #expect(r.stdout.contains("list"))
        #expect(r.stdout.contains("remove"))
    }

    @Test("virtual with unknown subcommand exits 2")
    func unknownSubcommand() throws {
        let fx = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let r = run(args: ["virtual", "explode"], fixture: fx, log: log)
        #expect(r.exitCode == 2)
    }
}
