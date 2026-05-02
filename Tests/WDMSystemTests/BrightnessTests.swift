import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

@Suite("Brightness — fixture")
struct BrightnessFixtureTests {

    private func makeFixture(b1: Float?, b2: Float?) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-bri-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        let b1s = b1.map { String($0) } ?? "null"
        let b2s = b2.map { String($0) } ?? "null"
        let json = """
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
          },
          "brightness": { "1": \(b1s), "2": \(b2s) }
        }
        """
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test("brightness(for:) returns the value stored in fixture")
    func reads() throws {
        let url = try makeFixture(b1: 0.5, b2: nil)
        let p = try FixtureDisplayProvider(fixtureURL: url)
        #expect(try p.brightness(for: 1) == 0.5)
        #expect(try p.brightness(for: 2) == nil)
    }

    @Test("setBrightness clamps to [0,1] and persists")
    func setsAndPersists() throws {
        let url = try makeFixture(b1: 0.5, b2: nil)
        let p = try FixtureDisplayProvider(fixtureURL: url)
        _ = try p.setBrightness(displayID: 1, value: 0.9, options: .noConfirm)
        #expect(try p.brightness(for: 1) == 0.9)

        let p2 = try FixtureDisplayProvider(fixtureURL: url)
        #expect(try p2.brightness(for: 1) == 0.9)
    }

    @Test("setBrightness rejects out-of-range")
    func rejectsOutOfRange() throws {
        let url = try makeFixture(b1: 0.5, b2: nil)
        let p = try FixtureDisplayProvider(fixtureURL: url)
        #expect(throws: ProviderError.self) {
            _ = try p.setBrightness(displayID: 1, value: 1.5, options: .noConfirm)
        }
        #expect(throws: ProviderError.self) {
            _ = try p.setBrightness(displayID: 1, value: -0.1, options: .noConfirm)
        }
    }

    @Test("setBrightness on display without brightness support throws")
    func unsupportedThrows() throws {
        let url = try makeFixture(b1: 0.5, b2: nil)
        let p = try FixtureDisplayProvider(fixtureURL: url)
        #expect(throws: ProviderError.self) {
            _ = try p.setBrightness(displayID: 2, value: 0.5, options: .noConfirm)
        }
    }
}

@Suite("Brightness — real hardware (gated, idempotent)",
       .enabled(if: ProcessInfo.processInfo.environment["WDM_REAL_HARDWARE"] == "1"))
struct BrightnessRealHardwareTests {

    @Test("brightness(for:) on built-in returns 0...1 or nil")
    func readsBuiltIn() throws {
        let provider = CGDisplayProvider()
        let snap = try provider.snapshot()
        let mainID = snap.main!.id
        let b = try provider.brightness(for: mainID)
        if let b {
            #expect(b >= 0 && b <= 1)
        }
    }

    @Test("setBrightness round-trip restores original")
    func roundTrip() throws {
        let provider = CGDisplayProvider()
        let mainID = try provider.snapshot().main!.id
        guard let original = try provider.brightness(for: mainID) else { return }
        defer { _ = try? provider.setBrightness(displayID: mainID, value: original, options: .noConfirm) }
        _ = try provider.setBrightness(displayID: mainID, value: original, options: .noConfirm)
        let after = try provider.brightness(for: mainID)
        if let after {
            #expect(abs(after - original) < 0.05)
        }
    }
}
