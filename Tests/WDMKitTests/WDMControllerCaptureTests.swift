import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController shotAll + panorama")
struct WDMControllerCaptureTests {
    @Test("shotAll writes one PNG per active display and returns the paths")
    func shotAll() throws {
        let (controller, _, dir) = try makeController()
        let outDir = dir.appendingPathComponent("shots")
        let recorder = RecordingScreenshotter(logURL: dir.appendingPathComponent("log.txt"))
        let paths = try controller.shotAll(to: outDir, using: recorder)
        #expect(paths.count == 2)
        #expect(paths.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }

    @Test("panorama composes one PNG covering every display")
    func panorama() throws {
        let (controller, _, dir) = try makeController()
        let outURL = dir.appendingPathComponent("pano.png")
        let recorder = RecordingScreenshotter(logURL: dir.appendingPathComponent("log.txt"))
        let result = try controller.panorama(to: outURL, using: recorder)
        #expect(result.displayCount == 2)
        #expect(FileManager.default.fileExists(atPath: outURL.path))
    }

    private func makeController() throws -> (WDMController, FixtureDisplayProvider, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-cap-\(UUID().uuidString)")
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
