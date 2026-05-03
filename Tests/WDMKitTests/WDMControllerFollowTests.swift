import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController follow")
struct WDMControllerFollowTests {
    @Test("follow spawns a PIP each time the cursor lands on a different display")
    func followSpawnsPip() throws {
        let (controller, dir) = try makeController()
        let cursor = OneShotCursor(values: [2, 2, 1])
        let pipLog = dir.appendingPathComponent("pip.log")
        let pip = RecordingPipFlipper(url: pipLog)
        let plan = WDMController.FollowPlan(
            destinationAlias: "main", pollMs: 1, durationMs: nil
        )
        try controller.follow(plan: plan, cursor: cursor, pip: pip)
        let log = (try? String(contentsOf: pipLog, encoding: .utf8)) ?? ""
        let lines = log.split(separator: "\n")
        #expect(lines.count == 1)
        #expect(log.contains("source=2"))
        #expect(log.contains("destination=1"))
    }

    private func makeController() throws -> (WDMController, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-follow-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: url, atomically: true, encoding: .utf8)
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        let controller = WDMController(
            provider: provider,
            profileStore: ProfileStore(directory: dir.appendingPathComponent("profiles")),
            env: [:]
        )
        return (controller, dir)
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

/// Cursor that yields the configured sequence then returns nil — distinct from
/// `RecordingCursorTracker` which cycles forever, so it gives `follow` a clean
/// terminator for hermetic tests.
private final class OneShotCursor: CursorTracker, @unchecked Sendable {
    private let lock = NSLock()
    private let values: [UInt32]
    private var idx: Int = 0
    init(values: [UInt32]) { self.values = values }
    func currentDisplayID() -> UInt32? {
        lock.withLock {
            guard idx < values.count else { return nil }
            defer { idx += 1 }
            return values[idx]
        }
    }
}
