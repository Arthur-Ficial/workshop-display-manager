import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController edid")
struct WDMControllerEdidTests {
    @Test("edid throws edidUnavailable when the display has no EDID")
    func unavailable() throws {
        let controller = try makeController()
        #expect(throws: WDMError.edidUnavailable(1).self) {
            _ = try controller.edid("1")
        }
    }

    private func makeController() throws -> WDMController {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-edid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: url, atomically: true, encoding: .utf8)
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        return WDMController(provider: provider,
                             profileStore: ProfileStore(directory: dir.appendingPathComponent("profiles")),
                             env: [:])
    }

    private static let fixtureJSON = """
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
          }
        ]
      },
      "availableModes": { "1": [{ "width": 2560, "height": 1664, "refreshHz": 60 }] }
    }
    """
}
