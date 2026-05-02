import Testing
import Foundation
@testable import WDMCore

@Suite("EDIDHasher")
struct EDIDHasherTests {

    @Test("hash is identical for the same set of displays in any order")
    func orderInvariant() {
        let a = [DisplayInfo.fixture(id: 1, name: "A"),
                 DisplayInfo.fixture(id: 2, name: "B")]
        let b = [DisplayInfo.fixture(id: 2, name: "B"),
                 DisplayInfo.fixture(id: 1, name: "A")]
        #expect(EDIDHasher.hash(of: a) == EDIDHasher.hash(of: b))
    }

    @Test("hash differs when a display is added or removed")
    func setSensitive() {
        let a = [DisplayInfo.fixture(id: 1, name: "A")]
        let b = [DisplayInfo.fixture(id: 1, name: "A"),
                 DisplayInfo.fixture(id: 2, name: "B")]
        #expect(EDIDHasher.hash(of: a) != EDIDHasher.hash(of: b))
    }

    @Test("hash ignores transient state — main, mirror, mode")
    func transientState() {
        let a = [DisplayInfo.fixture(id: 1, name: "A", isMain: true,
                                     mode: Mode(width: 1920, height: 1080, refreshHz: 60))]
        let b = [DisplayInfo.fixture(id: 1, name: "A", isMain: false,
                                     mode: Mode(width: 2560, height: 1440, refreshHz: 60))]
        // Same identity (id+name), different transient state — must hash equal so
        // that the daemon recognises this is the same physical display.
        #expect(EDIDHasher.hash(of: a) == EDIDHasher.hash(of: b))
    }

    @Test("hash is stable hex of fixed length")
    func stableLength() {
        let a = [DisplayInfo.fixture(id: 1, name: "A")]
        let h = EDIDHasher.hash(of: a)
        #expect(h.count == 16)
        #expect(h.allSatisfy { $0.isHexDigit })
    }
}

private extension DisplayInfo {
    static func fixture(
        id: UInt32, name: String,
        isMain: Bool = true,
        mode: Mode = Mode(width: 1920, height: 1080, refreshHz: 60)
    ) -> DisplayInfo {
        DisplayInfo(
            id: id, name: name, isMain: isMain, isOnline: true,
            mirrorSource: nil, currentMode: mode,
            origin: Point(x: 0, y: 0), rotationDegrees: 0
        )
    }
}
