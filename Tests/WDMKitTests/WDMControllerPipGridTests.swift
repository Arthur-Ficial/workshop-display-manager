import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController pipGrid")
struct WDMControllerPipGridTests {
    @Test("pipGrid plans 4 sources into a 2x2 grid on the destination")
    func planTwoByTwo() throws {
        let (controller, _, _) = try makeController()
        let plan = WDMController.PipGridPlan(
            sourceAliases: ["1", "2", "3", "4"],
            destinationAlias: "1",
            cols: 2,
            durationMs: nil,
            margin: 8
        )
        let placements = try controller.pipGridLayout(plan: plan)
        #expect(placements.count == 4)
        #expect(placements[0].size.width == placements[1].size.width)
        #expect(placements[0].position?.x ?? -1 < placements[1].position?.x ?? -1)
        #expect(placements[2].position?.y ?? -1 > placements[0].position?.y ?? -1)
    }

    @Test("pipGrid uses computed cols when not specified (sqrt-ceil)")
    func defaultCols() throws {
        let (controller, _, _) = try makeController()
        let plan = WDMController.PipGridPlan(
            sourceAliases: ["1", "2", "3"],
            destinationAlias: "1",
            cols: nil, durationMs: nil, margin: 8
        )
        let placements = try controller.pipGridLayout(plan: plan)
        #expect(placements.count == 3)
    }

    @Test("pipGrid runs every placement through the supplied flipper")
    func runPlacements() throws {
        let (controller, _, dir) = try makeController()
        let log = dir.appendingPathComponent("pip.log")
        let pip = RecordingPipFlipper(url: log)
        let plan = WDMController.PipGridPlan(
            sourceAliases: ["2"],
            destinationAlias: "1",
            cols: 1, durationMs: 1, margin: 8
        )
        try controller.pipGrid(plan: plan, using: pip)
        let contents = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        #expect(contents.contains("source=2"))
        #expect(contents.contains("destination=1"))
    }

    private func makeController() throws -> (WDMController, FixtureDisplayProvider, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-pipgrid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: url, atomically: true, encoding: .utf8)
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        let controller = WDMController(
            provider: provider,
            profileStore: ProfileStore(directory: dir.appendingPathComponent("profiles")),
            env: [:]
        )
        return (controller, provider, dir)
    }

    private static let fixtureJSON = """
    {
      "snapshot": {
        "createdAt": 1700000000,
        "displays": [
          { "id": 1, "name": "A", "isMain": true, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
            "origin": { "x": 0, "y": 0 }, "rotationDegrees": 0 },
          { "id": 2, "name": "B", "isMain": false, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
            "origin": { "x": 1920, "y": 0 }, "rotationDegrees": 0 },
          { "id": 3, "name": "C", "isMain": false, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
            "origin": { "x": 3840, "y": 0 }, "rotationDegrees": 0 },
          { "id": 4, "name": "D", "isMain": false, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
            "origin": { "x": 5760, "y": 0 }, "rotationDegrees": 0 }
        ]
      },
      "availableModes": {
        "1": [{ "width": 1920, "height": 1080, "refreshHz": 60 }],
        "2": [{ "width": 1920, "height": 1080, "refreshHz": 60 }],
        "3": [{ "width": 1920, "height": 1080, "refreshHz": 60 }],
        "4": [{ "width": 1920, "height": 1080, "refreshHz": 60 }]
      }
    }
    """
}
