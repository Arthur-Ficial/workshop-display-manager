import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController rename")
struct WDMControllerRenameTests {
    @Test("rename writes to the alias overlay store and returns the canonical name")
    func upsert() throws {
        let (controller, store) = try makeController()
        let outcome = try controller.rename("1", to: "Workshop", store: store)
        #expect(outcome.name == "Workshop")
        #expect(outcome.displayID == 1)
        // Backing store has it persisted.
        let map = try store.load()
        #expect(map.values.contains("Workshop"))
    }

    @Test("removeRename removes the alias and returns true; missing returns false")
    func removeRoundTrip() throws {
        let (controller, store) = try makeController()
        _ = try controller.rename("1", to: "Workshop", store: store)
        #expect(try controller.removeRename("1", store: store) == true)
        #expect(try controller.removeRename("1", store: store) == false)
    }

    private func makeController() throws -> (WDMController, DisplayAliasStore) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-rename-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: url, atomically: true, encoding: .utf8)
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        let controller = WDMController(
            provider: provider,
            profileStore: ProfileStore(directory: dir.appendingPathComponent("profiles")),
            env: [:]
        )
        let store = DisplayAliasStore(url: dir.appendingPathComponent("aliases.json"))
        return (controller, store)
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
