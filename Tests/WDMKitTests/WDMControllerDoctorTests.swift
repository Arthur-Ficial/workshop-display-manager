import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController doctor")
struct WDMControllerDoctorTests {
    @Test("doctorProbe with no alias returns one report per active display")
    func probeAll() throws {
        let (controller, _) = try makeController()
        let reports = try controller.doctorProbe(alias: nil)
        #expect(reports.count == 2)
        #expect(reports[0].displayID == 1)
        #expect(reports[0].isMain == true)
        #expect(reports[1].displayID == 2)
    }

    @Test("doctorProbe with an alias returns just that display")
    func probeOne() throws {
        let (controller, _) = try makeController()
        let reports = try controller.doctorProbe(alias: "2")
        #expect(reports.count == 1)
        #expect(reports[0].displayID == 2)
    }

    @Test("doctorDisconnect captures and releases the supplied display")
    func disconnect() throws {
        let (controller, dir) = try makeController()
        let log = dir.appendingPathComponent("cap.log")
        let capturer = RecordingDisplayCapturer(url: log)
        let plan = WDMController.DoctorDisconnectPlan(alias: "2", durationMs: 1)
        try controller.doctorDisconnect(plan: plan, using: capturer)
        let contents = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        #expect(contents.contains("capture id=2"))
        #expect(contents.contains("release id=2"))
    }

    private func makeController() throws -> (WDMController, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-doctor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: url, atomically: true, encoding: .utf8)
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        let controller = WDMController(
            provider: provider,
            profileStore: ProfileStore(directory: dir.appendingPathComponent("p")),
            env: [:]
        )
        return (controller, dir)
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
