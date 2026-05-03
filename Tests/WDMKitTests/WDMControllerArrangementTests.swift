import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController arrangement")
struct WDMControllerArrangementTests {
    @Test("arrangement returns the current origin + rotation per display")
    func read() throws {
        let (controller, _) = try makeController()
        let arr = try controller.arrangement()
        #expect(arr.count == 2)
        #expect(arr[0].id == 1)
        #expect(arr[0].origin == Point(x: 0, y: 0))
        #expect(arr[1].origin == Point(x: 2560, y: 0))
    }

    @Test("setArrangement moves multiple displays in one call")
    func bulkMove() throws {
        let (controller, provider) = try makeController()
        let plan = [
            ArrangementEntry(id: 1, origin: Point(x: -1920, y: 0)),
            ArrangementEntry(id: 2, origin: Point(x: 0, y: 0)),
        ]
        let result = try controller.setArrangement(plan, confirmer: AutoYesConfirmer())
        #expect(result == .applied)
        let snap = try provider.snapshot()
        #expect(snap.display(id: 1)?.origin == Point(x: -1920, y: 0))
        #expect(snap.display(id: 2)?.origin == Point(x: 0, y: 0))
    }

    @Test("setArrangement on unknown display throws displayNotFound")
    func unknownDisplay() throws {
        let (controller, _) = try makeController()
        #expect(throws: WDMError.displayNotFound(999).self) {
            _ = try controller.setArrangement(
                [ArrangementEntry(id: 999, origin: Point(x: 0, y: 0))],
                confirmer: AutoYesConfirmer()
            )
        }
    }

    private func makeController() throws -> (WDMController, FixtureDisplayProvider) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-arr-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: url, atomically: true, encoding: .utf8)
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        let controller = WDMController(
            provider: provider,
            profileStore: ProfileStore(directory: dir.appendingPathComponent("p")),
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
