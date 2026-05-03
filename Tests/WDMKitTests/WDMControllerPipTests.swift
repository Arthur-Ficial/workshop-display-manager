import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController pip")
struct WDMControllerPipTests {
    @Test("pip routes source/destination through the flipper at the configured size+flip")
    func runPip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-pip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: url, atomically: true, encoding: .utf8)
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        let controller = WDMController(
            provider: provider,
            profileStore: ProfileStore(directory: dir.appendingPathComponent("p")),
            env: [:]
        )
        let log = dir.appendingPathComponent("pip.log")
        let pip = RecordingPipFlipper(url: log)

        let plan = WDMController.PipPlan(
            sourceAlias: "2",
            destinationAlias: "main",
            size: PipSize(width: 640, height: 480),
            position: PipPosition(x: 10, y: 20),
            flip: .horizontal,
            durationMs: 1,
            remoteControl: false
        )
        try controller.pip(plan: plan, using: pip)
        let contents = try String(contentsOf: log, encoding: .utf8)
        #expect(contents.contains("source=2"))
        #expect(contents.contains("destination=1"))
        #expect(contents.contains("size=640x480"))
        #expect(contents.contains("position=10,20"))
        #expect(contents.contains("flip=horizontal"))
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
            "origin": { "x": 1920, "y": 0 }, "rotationDegrees": 0 }
        ]
      },
      "availableModes": {
        "1": [{ "width": 1920, "height": 1080, "refreshHz": 60 }],
        "2": [{ "width": 1920, "height": 1080, "refreshHz": 60 }]
      }
    }
    """
}
