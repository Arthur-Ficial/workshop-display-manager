import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController scale")
struct WDMControllerScaleTests {
    @Test("controller owns scale option selection")
    func scaleOptionsAndApply() throws {
        let (controller, provider) = try makeController()

        #expect(try controller.scaleOptions("1").map(\.label) == ["2560x1664", "1920x1200"])
        #expect(try controller.scale("1", width: 1920, height: 1200,
                                     confirmer: AutoYesConfirmer()) == .applied)
        #expect(try provider.snapshot().display(id: 1)?.currentMode.description == "1920x1200@60")
    }

    private func makeController() throws -> (WDMController, FixtureDisplayProvider) {
        let fixture = try makeFixture()
        let provider = try FixtureDisplayProvider(fixtureURL: fixture)
        let profiles = try makeTempDirectory().appendingPathComponent("profiles")
        return (WDMController(provider: provider, profileStore: ProfileStore(directory: profiles), env: [:]),
                provider)
    }

    private func makeFixture() throws -> URL {
        let url = try makeTempDirectory().appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-kit-scale-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static let fixtureJSON = """
    {
      "snapshot": {
        "createdAt": 1700000000,
        "displays": [
          { "id": 1, "name": "Built-in", "isMain": true, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 2560, "height": 1664, "refreshHz": 60 },
            "origin": { "x": 0, "y": 0 }, "rotationDegrees": 0 }
        ]
      },
      "availableModes": {
        "1": [
          { "width": 2560, "height": 1664, "refreshHz": 60 },
          { "width": 1920, "height": 1200, "refreshHz": 60 }
        ]
      }
    }
    """
}
