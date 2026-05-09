import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm daemon (e2e)")
struct DaemonE2ETests {

    private func tempProfilesDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-daemon-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeEventsFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-daemon-evt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("events.jsonl")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return url
    }

    private func run(_ args: [String], fixture: URL, profilesDir: URL, events: URL? = nil) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        var env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_PROFILES_DIR": profilesDir.path,
        ]
        if let events { env["WDM_TEST_EVENTS_FILE"] = events.path }
        let code = CLITestHarness.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("on event, daemon auto-restores the matching auto-profile")
    func autoRestore() async throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()
        let evts = try makeEventsFile()

        // 1. Save current arrangement keyed by EDID set: id 1 is main.
        _ = run(["save", "--auto"], fixture: fx, profilesDir: pd)

        // 2. Mutate the fixture so that id 2 is now main (simulates an unrelated change).
        _ = run(["main", "2", "--no-confirm"], fixture: fx, profilesDir: pd)
        let mid = run(["get", "main", "id"], fixture: fx, profilesDir: pd)
        #expect(mid.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "2")

        // 3. Producer writes an event to wake up the daemon.
        let producer = Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            let h = try FileHandle(forWritingTo: evts)
            defer { try? h.close() }
            try h.seekToEnd()
            let e = DisplayEvent(timestamp: Date(), kind: .added, displayID: 2)
            try h.write(contentsOf: try JSONEncoder().encode(e))
            try h.write(contentsOf: Data("\n".utf8))
        }

        // 4. Daemon: process exactly one event, restore matching profile, exit.
        let r = run(["daemon", "--max-events", "1"], fixture: fx, profilesDir: pd, events: evts)
        _ = await producer.result
        #expect(r.exitCode == 0)

        // 5. Daemon should have restored id 1 as main.
        let after = run(["get", "main", "id"], fixture: fx, profilesDir: pd)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }

    @Test("daemon --help exits 0 with usage (issue #5)")
    func helpFlag() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()
        let r = run(["daemon", "--help"], fixture: fx, profilesDir: pd)
        #expect(r.exitCode == 0)
        #expect(r.stderr.contains("daemon"))
    }

    @Test("daemon -h exits 0 with usage")
    func helpDashH() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()
        let r = run(["daemon", "-h"], fixture: fx, profilesDir: pd)
        #expect(r.exitCode == 0)
    }

    @Test("daemon install --to <path> writes a LaunchAgent plist")
    func install() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempProfilesDir()
        let target = pd.appendingPathComponent("LaunchAgent.plist")
        let r = run(["daemon", "install", "--to", target.path],
                    fixture: fx, profilesDir: pd)
        #expect(r.exitCode == 0)
        #expect(FileManager.default.fileExists(atPath: target.path))
        let contents = try String(contentsOf: target, encoding: .utf8)
        #expect(contents.contains("<key>Label</key>"))
        #expect(contents.contains("com.fullstackoptimization.wdm"))
        #expect(contents.contains("<key>RunAtLoad</key>"))
        #expect(contents.contains("<key>KeepAlive</key>"))
    }
}
