import Testing
import Foundation
@testable import WDMCore

@Suite("DisplayInfo")
struct DisplayInfoTests {

    private func sample() -> DisplayInfo {
        DisplayInfo(
            id: 69733382,
            name: "Built-in Retina Display",
            isMain: true,
            isOnline: true,
            mirrorSource: nil,
            currentMode: Mode(width: 2560, height: 1664, refreshHz: 60),
            origin: Point(x: 0, y: 0),
            rotationDegrees: 0
        )
    }

    @Test("isMirrored derives from mirrorSource")
    func isMirrored() {
        var d = sample()
        #expect(d.isMirrored == false)
        d = DisplayInfo(
            id: d.id, name: d.name, isMain: false, isOnline: true,
            mirrorSource: 69733382,
            currentMode: d.currentMode, origin: d.origin, rotationDegrees: 0
        )
        #expect(d.isMirrored == true)
    }

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = sample()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DisplayInfo.self, from: data)
        #expect(decoded == original)
    }
}

@Suite("Snapshot")
struct SnapshotTests {

    private func sample() -> Snapshot {
        Snapshot(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            displays: [
                DisplayInfo(id: 1, name: "A", isMain: true, isOnline: true,
                            mirrorSource: nil,
                            currentMode: Mode(width: 1920, height: 1080, refreshHz: 60),
                            origin: Point(x: 0, y: 0), rotationDegrees: 0),
                DisplayInfo(id: 2, name: "B", isMain: false, isOnline: true,
                            mirrorSource: nil,
                            currentMode: Mode(width: 2560, height: 1440, refreshHz: 60),
                            origin: Point(x: 1920, y: 0), rotationDegrees: 90),
            ]
        )
    }

    @Test("Snapshot Codable round-trip")
    func roundTrip() throws {
        let original = sample()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Snapshot.self, from: data)
        #expect(decoded == original)
    }

    @Test("Snapshot lookup by id")
    func lookupById() {
        let s = sample()
        #expect(s.display(id: 1)?.name == "A")
        #expect(s.display(id: 2)?.name == "B")
        #expect(s.display(id: 999) == nil)
    }

    @Test("Snapshot main display")
    func mainDisplay() {
        let s = sample()
        #expect(s.main?.id == 1)
    }
}
