import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController daemon")
struct WDMControllerDaemonTests {
    @Test("watchAndRestore consumes events up to max and reports outcome counts")
    func consumeMaxOne() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-daemon-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let log = dir.appendingPathComponent("events.jsonl")
        let event = DisplayEvent(
            timestamp: Date(timeIntervalSince1970: 0), kind: .added, displayID: 1
        )
        let data = try JSONEncoder().encode(event)
        try (String(decoding: data, as: UTF8.self) + "\n").data(using: .utf8)!.write(to: log)

        let stream = EventStreamFile(url: log)
        let fixture = dir.appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: fixture, atomically: true, encoding: .utf8)
        let provider = try FixtureDisplayProvider(fixtureURL: fixture)
        let profileStore = ProfileStore(directory: dir.appendingPathComponent("profiles"))
        let auto = AutoProfileStore.resolve(from: profileStore)

        let outcome = try await WDMController.daemon.watchAndRestore(
            stream: stream, provider: provider, auto: auto, max: 1
        )
        #expect(outcome.eventsHandled == 1)
        #expect(outcome.profilesApplied == 0)
    }

    private static let fixtureJSON = """
    {
      "snapshot": {
        "createdAt": 1700000000,
        "displays": [
          { "id": 1, "name": "A", "isMain": true, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
            "origin": { "x": 0, "y": 0 }, "rotationDegrees": 0 }
        ]
      },
      "availableModes": {
        "1": [{ "width": 1920, "height": 1080, "refreshHz": 60 }]
      }
    }
    """
}
