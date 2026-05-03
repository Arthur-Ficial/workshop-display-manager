import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController workshop")
struct WDMControllerWorkshopTests {
    @Test("workshop start saves a snapshot named 'last-workshop' and switches main")
    func startSavesAndSwitches() throws {
        let (controller, provider) = try makeController()
        let result = try controller.workshopStart(audience: "2", confirmer: AutoYesConfirmer())
        #expect(result == .applied)
        #expect(try provider.snapshot().main?.id == 2)
        #expect(try controller.profiles().contains("last-workshop"))
    }

    @Test("workshop stop restores the previously saved snapshot")
    func stopRestores() throws {
        let (controller, provider) = try makeController()
        _ = try controller.workshopStart(audience: "2", confirmer: AutoYesConfirmer())
        try controller.workshopStop()
        #expect(try provider.snapshot().main?.id == 1)
    }

    private func makeController() throws -> (WDMController, FixtureDisplayProvider) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-workshop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: url, atomically: true, encoding: .utf8)
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        let controller = WDMController(
            provider: provider,
            profileStore: ProfileStore(directory: dir.appendingPathComponent("profiles")),
            env: [:]
        )
        return (controller, provider)
    }

    private static let fixtureJSON = """
    {
      "snapshot": {
        "createdAt": 1700000000,
        "displays": [
          { "id": 1, "name": "Built-in", "isMain": true, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 2560, "height": 1664, "refreshHz": 60 },
            "origin": { "x": 0, "y": 0 }, "rotationDegrees": 0 },
          { "id": 2, "name": "Projector", "isMain": false, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
            "origin": { "x": 2560, "y": 0 }, "rotationDegrees": 0 }
        ]
      },
      "availableModes": {
        "1": [{ "width": 2560, "height": 1664, "refreshHz": 60 }],
        "2": [{ "width": 1920, "height": 1080, "refreshHz": 60 }]
      }
    }
    """
}
