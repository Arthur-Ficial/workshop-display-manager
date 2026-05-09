import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm save / restore / profiles (e2e)")
struct ProfileCommandsE2ETests {

    private func runWithProfilesDir(_ args: [String], fixture: URL, profilesDir: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_PROFILES_DIR": profilesDir.path,
        ]
        let code = CLITestHarness.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-profiles-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("save writes a profile JSON file")
    func saveWritesFile() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempDir()
        let result = runWithProfilesDir(["save", "room-A"], fixture: fx, profilesDir: pd)
        #expect(result.exitCode == 0)
        let path = pd.appendingPathComponent("room-A.json")
        #expect(FileManager.default.fileExists(atPath: path.path))
    }

    @Test("profiles lists saved names alphabetically")
    func listsProfiles() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempDir()
        _ = runWithProfilesDir(["save", "zebra"], fixture: fx, profilesDir: pd)
        _ = runWithProfilesDir(["save", "alpha"], fixture: fx, profilesDir: pd)
        let result = runWithProfilesDir(["profiles"], fixture: fx, profilesDir: pd)
        #expect(result.exitCode == 0)
        let lines = result.stdout
            .split(separator: "\n").map { String($0) }
            .filter { !$0.isEmpty }
        #expect(lines == ["alpha", "zebra"])
    }

    @Test("profiles --json emits JSON array")
    func profilesJSON() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempDir()
        _ = runWithProfilesDir(["save", "one"], fixture: fx, profilesDir: pd)
        let result = runWithProfilesDir(["profiles", "--json"], fixture: fx, profilesDir: pd)
        let parsed = try JSONSerialization.jsonObject(with: Data(result.stdout.utf8)) as? [String]
        #expect(parsed == ["one"])
    }

    @Test("profiles refuses when the profile directory cannot be read")
    func profilesListReadFailure() throws {
        let fx = try CLITestHarness.makeFixture()
        let badPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-profiles-file-\(UUID().uuidString)")
        try "not a directory".write(to: badPath, atomically: true, encoding: .utf8)

        let result = runWithProfilesDir(["profiles"], fixture: fx, profilesDir: badPath)
        #expect(result.exitCode == ExitCodes.ioError)
        #expect(result.stderr.contains("I/O error"))
    }

    @Test("restore applies a saved profile to fixture provider")
    func restoreApplies() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempDir()

        // Mutate fixture: make display 2 main and change its mode.
        _ = runWithProfilesDir(["save", "before"], fixture: fx, profilesDir: pd)
        // Manually edit the fixture to a different state by saving a different snapshot:
        let alt = try CLITestHarness.makeFixture("""
        {
          "snapshot": {
            "createdAt": 1700000000,
            "displays": [
              {
                "id": 1, "name": "Built-in", "isMain": false, "isOnline": true,
                "mirrorSource": null,
                "currentMode": { "width": 2560, "height": 1664, "refreshHz": 60 },
                "origin": { "x": 0, "y": 0 },
                "rotationDegrees": 0
              },
              {
                "id": 2, "name": "Projector", "isMain": true, "isOnline": true,
                "mirrorSource": null,
                "currentMode": { "width": 1280, "height": 720, "refreshHz": 60 },
                "origin": { "x": 2560, "y": 0 },
                "rotationDegrees": 90
              }
            ]
          },
          "availableModes": {
            "1": [
              { "width": 2560, "height": 1664, "refreshHz": 60 },
              { "width": 1920, "height": 1200, "refreshHz": 60 }
            ],
            "2": [
              { "width": 1920, "height": 1080, "refreshHz": 60 },
              { "width": 1280, "height": 720,  "refreshHz": 60 }
            ]
          }
        }
        """)
        _ = runWithProfilesDir(["save", "after"], fixture: alt, profilesDir: pd)

        // Restore "before" against the alt fixture and verify alt now matches "before".
        let result = runWithProfilesDir(
            ["restore", "before", "--no-confirm"],
            fixture: alt, profilesDir: pd
        )
        #expect(result.exitCode == 0)

        let listResult = runWithProfilesDir(["list", "--json"], fixture: alt, profilesDir: pd)
        let displays = try JSONSerialization.jsonObject(with: Data(listResult.stdout.utf8)) as? [[String: Any]]
        let main = displays?.first { ($0["isMain"] as? Bool) == true }
        #expect(main?["id"] as? Int == 1, "main should now be display 1 (built-in) again")
        let projector = displays?.first { ($0["id"] as? Int) == 2 }
        let mode = projector?["currentMode"] as? [String: Any]
        #expect(mode?["width"] as? Int == 1920)
    }

    @Test("restore unknown profile exits 6")
    func restoreUnknownExits6() throws {
        let fx = try CLITestHarness.makeFixture()
        let pd = try tempDir()
        let result = runWithProfilesDir(
            ["restore", "nope", "--no-confirm"],
            fixture: fx, profilesDir: pd
        )
        #expect(result.exitCode == 6)
    }
}
