import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController wallpaper (read)")
struct WDMControllerWallpaperTests {
    @Test("wallpaper returns the fixture-mapped URL for a known display")
    func mappedReturns() throws {
        let env = try makeEnvWithFixture(json: #"{"1":"/tmp/builtin.jpg","2":"/tmp/projector.jpg"}"#)
        let controller = try makeController(env: env)
        let url = try controller.wallpaper("1")
        #expect(url?.path == "/tmp/builtin.jpg")
    }

    @Test("wallpaper returns nil when the display has no wallpaper set")
    func unsetReturnsNil() throws {
        let env = try makeEnvWithFixture(json: #"{"2":"/tmp/projector.jpg"}"#)
        let controller = try makeController(env: env)
        let url = try controller.wallpaper("1")
        #expect(url == nil)
    }

    @Test("wallpaper resolves alias 'main' to the main display")
    func resolvesMainAlias() throws {
        let env = try makeEnvWithFixture(json: #"{"1":"/tmp/builtin.jpg"}"#)
        let controller = try makeController(env: env)
        let byID = try controller.wallpaper("1")
        let byAlias = try controller.wallpaper("main")
        #expect(byID?.path == byAlias?.path)
    }

    @Test("setWallpaper applies and persists when confirmer keeps")
    func setWallpaperKeeps() throws {
        let env = try makeEnvWithFixture(json: #"{"1":"/tmp/old.jpg"}"#)
        let controller = try makeController(env: env)
        let result = try controller.setWallpaper(
            "1", url: URL(fileURLWithPath: "/tmp/new.jpg"),
            confirmer: AutoYesConfirmer()
        )
        #expect(result == .applied)
        #expect(try controller.wallpaper("1")?.path == "/tmp/new.jpg")
    }

    @Test("setWallpaper reverts to previous URL when confirmer rejects")
    func setWallpaperReverts() throws {
        let env = try makeEnvWithFixture(json: #"{"1":"/tmp/old.jpg"}"#)
        let controller = try makeController(env: env)
        let result = try controller.setWallpaper(
            "1", url: URL(fileURLWithPath: "/tmp/new.jpg"),
            confirmer: AutoNoConfirmer()
        )
        #expect(result == .reverted)
        #expect(try controller.wallpaper("1")?.path == "/tmp/old.jpg")
    }

    private func makeEnvWithFixture(json: String) throws -> [String: String] {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-wp-kit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("wallpaper.json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        return ["WDM_TEST_WALLPAPER": url.path]
    }

    private func makeController(env: [String: String]) throws -> WDMController {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-wp-ctrl-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let displayFixture = dir.appendingPathComponent("display-fixture.json")
        try Self.displayFixtureJSON.write(to: displayFixture, atomically: true, encoding: .utf8)
        let provider = try FixtureDisplayProvider(fixtureURL: displayFixture)
        return WDMController(
            provider: provider,
            profileStore: ProfileStore(directory: dir.appendingPathComponent("profiles")),
            env: env
        )
    }

    private static let displayFixtureJSON = """
    {
      "snapshot": {
        "createdAt": 1700000000,
        "displays": [
          {
            "id": 1, "name": "Built-in", "isMain": true, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 2560, "height": 1664, "refreshHz": 60 },
            "origin": { "x": 0, "y": 0 },
            "rotationDegrees": 0
          },
          {
            "id": 2, "name": "Projector", "isMain": false, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
            "origin": { "x": 2560, "y": 0 },
            "rotationDegrees": 0
          }
        ]
      },
      "availableModes": {
        "1": [{ "width": 2560, "height": 1664, "refreshHz": 60 }],
        "2": [{ "width": 1920, "height": 1080, "refreshHz": 60 }]
      }
    }
    """
}
