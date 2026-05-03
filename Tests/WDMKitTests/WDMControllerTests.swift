import Foundation
import Testing
import WDMCore
import WDMSystem
@testable import WDMKit

@Suite("WDMController")
struct WDMControllerTests {
    @Test("read operations return typed values without formatting")
    func readOperations() throws {
        let controller = try makeController()

        #expect(try controller.list().map(\.id) == [1, 2])
        #expect(try controller.get("main").id == 1)
        #expect(try controller.get("2", field: .name) == .text("Projector"))
        #expect(try controller.modes("2").map(\.description) == ["1920x1080@60", "1280x720@60"])
        #expect(try controller.brightness("1") == 0.5)
    }

    @Test("mutating operations resolve aliases and persist through the provider")
    func mutatingOperations() throws {
        let (controller, provider) = try makeControllerAndProvider()

        #expect(try controller.main("2", confirmer: AutoYesConfirmer()) == .applied)
        #expect(try provider.snapshot().main?.id == 2)

        #expect(try controller.mode("2", mode: Mode(width: 1280, height: 720, refreshHz: 60),
                                    confirmer: AutoYesConfirmer()) == .applied)
        #expect(try provider.snapshot().display(id: 2)?.currentMode.description == "1280x720@60")

        #expect(try controller.move("2", to: Point(x: -1920, y: 0),
                                    confirmer: AutoYesConfirmer()) == .applied)
        #expect(try provider.snapshot().display(id: 2)?.origin == Point(x: -1920, y: 0))

        #expect(try controller.rotate("2", degrees: 90, confirmer: AutoYesConfirmer()) == .applied)
        #expect(try provider.snapshot().display(id: 2)?.rotationDegrees == 90)

        #expect(try controller.flip("2", flip: .vertical, confirmer: AutoYesConfirmer()) == .applied)
        #expect(try provider.flip(for: 2) == .vertical)

        #expect(try controller.mirror(source: "1", targets: ["2"], confirmer: AutoYesConfirmer()) == .applied)
        #expect(try provider.snapshot().display(id: 2)?.mirrorSource == 1)

        #expect(try controller.unmirror("2", confirmer: AutoYesConfirmer()) == .applied)
        #expect(try provider.snapshot().display(id: 2)?.mirrorSource == nil)

        #expect(try controller.brightness("1", value: 0.75, confirmer: AutoYesConfirmer()) == .applied)
        #expect(try provider.brightness(for: 1) == 0.75)
    }

    @Test("controller maps provider errors into WDMError")
    func mapsProviderErrors() throws {
        let controller = try makeController()

        #expect(throws: WDMError.displayNotFound(999)) {
            _ = try controller.get("999")
        }
        #expect(throws: WDMError.modeNotSupported("99999x99999@60")) {
            _ = try controller.mode("2", mode: Mode(width: 99999, height: 99999, refreshHz: 60),
                                    confirmer: AutoYesConfirmer())
        }
    }

    @Test("controller owns switch cycle and profile operations")
    func switchCycleAndProfiles() throws {
        let (controller, provider) = try makeControllerAndProvider()

        try controller.saveProfile("before")
        #expect(try controller.profiles() == ["before"])

        #expect(try controller.switchMain(confirmer: AutoYesConfirmer()) == .applied)
        #expect(try provider.snapshot().main?.id == 2)

        #expect(try controller.cycleMain(confirmer: AutoYesConfirmer()) == .applied)
        #expect(try provider.snapshot().main?.id == 1)

        _ = try controller.main("2", confirmer: AutoYesConfirmer())
        #expect(try provider.snapshot().main?.id == 2)
        #expect(try controller.restoreProfile("before", confirmer: AutoYesConfirmer()) == .applied)
        #expect(try provider.snapshot().main?.id == 1)

        try controller.removeProfile("before")
        #expect(try controller.profiles() == ["last"])
    }

    private func makeController() throws -> WDMController {
        let (controller, _) = try makeControllerAndProvider()
        return controller
    }

    private func makeControllerAndProvider() throws -> (WDMController, FixtureDisplayProvider) {
        let provider = try FixtureDisplayProvider(fixtureURL: makeFixture())
        let profileStore = ProfileStore(directory: makeTempDirectory().appendingPathComponent("profiles"))
        return (WDMController(provider: provider, profileStore: profileStore, env: [:]), provider)
    }

    private func makeFixture() throws -> URL {
        let url = makeTempDirectory().appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-kit-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
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
        "1": [
          { "width": 2560, "height": 1664, "refreshHz": 60 },
          { "width": 1920, "height": 1200, "refreshHz": 60 }
        ],
        "2": [
          { "width": 1920, "height": 1080, "refreshHz": 60 },
          { "width": 1280, "height": 720,  "refreshHz": 60 }
        ]
      },
      "brightness": {
        "1": 0.5,
        "2": null
      }
    }
    """
}
