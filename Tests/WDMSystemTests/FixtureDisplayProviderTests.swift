import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

@Suite("FixtureDisplayProvider")
struct FixtureDisplayProviderTests {

    private func makeFixtureFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        let json = """
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
          }
        }
        """
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test("loads snapshot from fixture file")
    func loadsSnapshot() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        let snap = try provider.snapshot()
        #expect(snap.displays.count == 2)
        #expect(snap.main?.id == 1)
        #expect(snap.display(id: 2)?.name == "Projector")
    }

    @Test("modes(for:) returns fixture-defined modes")
    func returnsModes() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        let modes = try provider.modes(for: 2)
        #expect(modes.count == 2)
        #expect(modes.contains(Mode(width: 1920, height: 1080, refreshHz: 60)))
    }

    @Test("modes(for:) for unknown display throws displayNotFound")
    func unknownDisplayThrows() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        #expect(throws: ProviderError.displayNotFound(999)) {
            _ = try provider.modes(for: 999)
        }
    }

    @Test("setMain swaps which display is main and persists to fixture")
    func setMainPersists() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        _ = try provider.setMain(displayID: 2, options: .noConfirm)
        let snap = try provider.snapshot()
        #expect(snap.main?.id == 2)
        #expect(snap.display(id: 1)?.isMain == false)

        // Reload provider — change must have been persisted to fixture file.
        let reloaded = try FixtureDisplayProvider(fixtureURL: url)
        #expect(try reloaded.snapshot().main?.id == 2)
    }

    @Test("setMain on unknown display throws displayNotFound")
    func setMainUnknownThrows() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        #expect(throws: ProviderError.displayNotFound(7)) {
            _ = try provider.setMain(displayID: 7, options: .noConfirm)
        }
    }

    @Test("setMode applies the mode and is idempotent")
    func setMode() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        _ = try provider.setMode(
            displayID: 2,
            mode: Mode(width: 1280, height: 720, refreshHz: 60),
            options: .noConfirm
        )
        #expect(try provider.snapshot().display(id: 2)?.currentMode
                == Mode(width: 1280, height: 720, refreshHz: 60))
    }

    @Test("setMode rejects unsupported mode")
    func setModeUnsupported() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        #expect(throws: ProviderError.modeNotSupported) {
            _ = try provider.setMode(
                displayID: 2,
                mode: Mode(width: 99999, height: 99999, refreshHz: 60),
                options: .noConfirm
            )
        }
    }

    @Test("mirror sets mirror relationship; unmirror clears it")
    func mirrorRoundTrip() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        _ = try provider.mirror(source: 1, mirror: 2, options: .noConfirm)
        #expect(try provider.snapshot().display(id: 2)?.mirrorSource == 1)
        _ = try provider.unmirror(displayID: 2, options: .noConfirm)
        #expect(try provider.snapshot().display(id: 2)?.mirrorSource == nil)
    }

    @Test("move updates origin")
    func move() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        _ = try provider.move(displayID: 2, to: Point(x: -1920, y: 0), options: .noConfirm)
        #expect(try provider.snapshot().display(id: 2)?.origin == Point(x: -1920, y: 0))
    }

    @Test("rotate accepts only 0/90/180/270")
    func rotate() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        _ = try provider.rotate(displayID: 2, degrees: 90, options: .noConfirm)
        #expect(try provider.snapshot().display(id: 2)?.rotationDegrees == 90)
        #expect(throws: ProviderError.invalidRotation(45)) {
            _ = try provider.rotate(displayID: 2, degrees: 45, options: .noConfirm)
        }
    }

    @Test("flip defaults to .none for newly loaded fixtures")
    func flipDefault() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        #expect(try provider.flip(for: 1) == Flip.none)
        #expect(try provider.flip(for: 2) == Flip.none)
    }

    @Test("setFlip persists vertical / horizontal / both / none and is idempotent")
    func setFlipPersists() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)

        _ = try provider.setFlip(displayID: 2, flip: .vertical, options: .noConfirm)
        #expect(try provider.flip(for: 2) == .vertical)

        let reloaded = try FixtureDisplayProvider(fixtureURL: url)
        #expect(try reloaded.flip(for: 2) == .vertical)

        let r1 = try reloaded.setFlip(displayID: 2, flip: .vertical, options: .noConfirm)
        #expect(r1 == .noChange)

        _ = try reloaded.setFlip(displayID: 2, flip: .horizontal, options: .noConfirm)
        #expect(try reloaded.flip(for: 2) == .horizontal)

        _ = try reloaded.setFlip(displayID: 2, flip: .both, options: .noConfirm)
        #expect(try reloaded.flip(for: 2) == .both)

        _ = try reloaded.setFlip(displayID: 2, flip: .none, options: .noConfirm)
        #expect(try reloaded.flip(for: 2) == Flip.none)
    }

    @Test("setFlip on unknown display throws displayNotFound")
    func setFlipUnknownThrows() throws {
        let url = try makeFixtureFile()
        let provider = try FixtureDisplayProvider(fixtureURL: url)
        #expect(throws: ProviderError.displayNotFound(999)) {
            _ = try provider.setFlip(displayID: 999, flip: .vertical, options: .noConfirm)
        }
    }
}
