import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm wallpaper (e2e)")
struct WallpaperCommandE2ETests {
    @Test("wallpaper <id> prints the URL path to stdout")
    func readsPath() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-wp-cli-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let wpFixture = dir.appendingPathComponent("wallpapers.json")
        try #"{"1":"/tmp/builtin.jpg","2":"/tmp/projector.jpg"}"#
            .write(to: wpFixture, atomically: true, encoding: .utf8)

        let displayFx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(
            ["wallpaper", "1"], fixture: displayFx,
            extraEnv: ["WDM_TEST_WALLPAPER": wpFixture.path]
        )
        #expect(r.exitCode == 0)
        #expect(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "/tmp/builtin.jpg")
    }

    @Test("wallpaper <id> --json wraps the path in a JSON object")
    func jsonWrap() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-wp-cli-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let wpFixture = dir.appendingPathComponent("wallpapers.json")
        try #"{"1":"/tmp/builtin.jpg"}"#
            .write(to: wpFixture, atomically: true, encoding: .utf8)

        let displayFx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(
            ["wallpaper", "1", "--json"], fixture: displayFx,
            extraEnv: ["WDM_TEST_WALLPAPER": wpFixture.path]
        )
        #expect(r.exitCode == 0)
        let trimmed = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = trimmed.data(using: .utf8) ?? Data()
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(obj?["wallpaper"] as? String == "/tmp/builtin.jpg")
    }

    @Test("wallpaper <id> on display with no wallpaper exits 0 with empty stdout")
    func emptyOnUnset() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-wp-cli-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let wpFixture = dir.appendingPathComponent("wallpapers.json")
        try "{}".write(to: wpFixture, atomically: true, encoding: .utf8)

        let displayFx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(
            ["wallpaper", "1"], fixture: displayFx,
            extraEnv: ["WDM_TEST_WALLPAPER": wpFixture.path]
        )
        #expect(r.exitCode == 0)
        #expect(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "")
    }

    @Test("wallpaper without args exits 2 (usage error)")
    func usageNoArgs() throws {
        let displayFx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["wallpaper"], fixture: displayFx)
        #expect(r.exitCode == 2)
    }

    @Test("wallpaper set <id> <path> --no-confirm applies and persists")
    func setApplies() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-wp-cli-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let wpFixture = dir.appendingPathComponent("wallpapers.json")
        try #"{"1":"/tmp/old.jpg"}"#.write(to: wpFixture, atomically: true, encoding: .utf8)

        let displayFx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(
            ["wallpaper", "set", "1", "/tmp/new.jpg", "--no-confirm"],
            fixture: displayFx,
            extraEnv: ["WDM_TEST_WALLPAPER": wpFixture.path]
        )
        #expect(r.exitCode == 0)

        let bytes = try Data(contentsOf: wpFixture)
        let dict = (try JSONSerialization.jsonObject(with: bytes) as? [String: String]) ?? [:]
        #expect(dict["1"] == "/tmp/new.jpg")
    }

    @Test("wallpaper set without enough args exits 2 (usage error)")
    func setUsageError() throws {
        let displayFx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["wallpaper", "set", "1"], fixture: displayFx)
        #expect(r.exitCode == 2)
    }
}
