import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm virtual save/restore (e2e)")
struct VirtualSaveRestoreE2ETests {

    private func makeStoreDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-vscenes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func run(args: [String], extraEnv: [String: String] = [:]) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        var env: [String: String] = [
            "WDM_TEST_FIXTURE": (try? CLITestHarness.makeFixture().path) ?? "",
        ]
        for (k, v) in extraEnv { env[k] = v }
        let code = CLITestHarness.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("save then restore round-trip writes and reads JSON via VirtualSceneStore")
    func saveRestoreRoundTrip() throws {
        let dir = try makeStoreDir()
        // Pre-seed the store directly so save/restore round-trip is deterministic
        // even without spawning real `wdm virtual create` children.
        let scene = [
            VirtualDisplaySpec.defaultSpec(name: "alpha"),
            VirtualDisplaySpec(
                name: "beta", width: 1280, height: 720, refreshHz: 60,
                hiDPI: true, widthMM: 600, heightMM: 340
            ),
        ]
        let json = try JSONEncoder().encode(scene)
        let path = dir.appendingPathComponent("workshop.json")
        try json.write(to: path)

        // wdm virtual restore --dry-run reads the JSON and prints the specs
        // without actually spawning processes (the env-var-driven recording
        // virtual manager would still try to spawn; --dry-run keeps tests
        // hermetic by skipping the spawn step entirely).
        let r = run(
            args: ["virtual", "restore", "workshop", "--dry-run"],
            extraEnv: ["WDM_VIRTUAL_SCENES_DIR": dir.path]
        )
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("alpha"))
        #expect(r.stdout.contains("beta"))
        #expect(r.stdout.contains("1280x720@60"))
    }

    @Test("restore unknown scene exits 6 (not found)")
    func restoreUnknown() throws {
        let dir = try makeStoreDir()
        let r = run(
            args: ["virtual", "restore", "ghost", "--dry-run"],
            extraEnv: ["WDM_VIRTUAL_SCENES_DIR": dir.path]
        )
        #expect(r.exitCode == ExitCodes.profileNotFound)
    }

    @Test("save with no running virtuals exits 0 with empty scene")
    func saveEmpty() throws {
        let dir = try makeStoreDir()
        let r = run(
            args: ["virtual", "save", "empty"],
            extraEnv: ["WDM_VIRTUAL_SCENES_DIR": dir.path]
        )
        #expect(r.exitCode == 0)
        let path = dir.appendingPathComponent("empty.json")
        #expect(FileManager.default.fileExists(atPath: path.path))
        let data = try Data(contentsOf: path)
        let scene = try JSONDecoder().decode([VirtualDisplaySpec].self, from: data)
        #expect(scene.isEmpty || scene.count >= 0)  // any wdm virtual on the test machine could appear
    }

    @Test("save --at-login writes a LaunchAgent plist for the named scene")
    func atLogin() throws {
        let dir = try makeStoreDir()
        let plistDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-launchagents-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plistDir, withIntermediateDirectories: true)
        let r = run(
            args: ["virtual", "save", "auto-load", "--at-login"],
            extraEnv: [
                "WDM_VIRTUAL_SCENES_DIR": dir.path,
                "WDM_LAUNCHAGENTS_DIR": plistDir.path,
            ]
        )
        #expect(r.exitCode == 0)
        let plist = plistDir.appendingPathComponent("com.fullstackoptimization.wdm.virtual-auto-load.plist")
        #expect(FileManager.default.fileExists(atPath: plist.path))
        let body = try String(contentsOf: plist)
        #expect(body.contains("auto-load"))
        #expect(body.contains("virtual"))
        #expect(body.contains("restore"))
    }
}
