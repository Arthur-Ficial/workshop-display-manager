import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm scene (e2e)")
struct SceneCommandE2ETests {

    private func makeStoreDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-scenes-\(UUID().uuidString)")
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
        let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("scene <name> --dry-run lists every entry from JSON")
    func dryRun() throws {
        let dir = try makeStoreDir()
        let entries: [SceneEntry] = [
            SceneEntry(
                spec: VirtualDisplaySpec.defaultSpec(name: "audience"),
                wallpaper: "/System/Library/Desktop Pictures/iMac Green.heic",
                mirrorOn: 1
            ),
            SceneEntry(
                spec: VirtualDisplaySpec(
                    name: "preview", width: 1280, height: 720, refreshHz: 60,
                    hiDPI: true, widthMM: 600, heightMM: 340
                ),
                wallpaper: nil,
                mirrorOn: nil
            ),
        ]
        let data = try JSONEncoder().encode(entries)
        try data.write(to: dir.appendingPathComponent("workshop.json"))

        let r = run(
            args: ["scene", "workshop", "--dry-run"],
            extraEnv: ["WDM_SCENES_DIR": dir.path]
        )
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("audience"))
        #expect(r.stdout.contains("preview"))
        #expect(r.stdout.contains("1920x1080@60"))
        #expect(r.stdout.contains("1280x720@60"))
        #expect(r.stdout.contains("iMac Green.heic"))
        #expect(r.stdout.contains("mirror-on=1"))
    }

    @Test("scene <unknown> exits 6 (profile-not-found)")
    func unknown() throws {
        let dir = try makeStoreDir()
        let r = run(
            args: ["scene", "ghost", "--dry-run"],
            extraEnv: ["WDM_SCENES_DIR": dir.path]
        )
        #expect(r.exitCode == ExitCodes.profileNotFound)
    }

    @Test("scene without name exits 2 (usage)")
    func usage() throws {
        let dir = try makeStoreDir()
        let r = run(
            args: ["scene"],
            extraEnv: ["WDM_SCENES_DIR": dir.path]
        )
        #expect(r.exitCode == 2)
    }
}
