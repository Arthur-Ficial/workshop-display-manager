import Testing
import Foundation
@testable import WDMCore

@Suite("EDID parser (pure)")
struct EDIDTests {

    /// Build a minimal-but-valid 128-byte EDID for "DEL" manufacturer,
    /// product 0x4081, serial 0x12345678, week 25, year 2012, with a
    /// display name descriptor "TestMon" and a serial-string descriptor "ABC123".
    static func sample() -> [UInt8] {
        var b = [UInt8](repeating: 0, count: 128)
        // Header (bytes 0..7)
        b[0] = 0x00
        for i in 1...6 { b[i] = 0xFF }
        b[7] = 0x00
        // Manufacturer "DEL" → 5-bit packed, bytes 8-9 big-endian.
        // D=4, E=5, L=12 → (4<<10)|(5<<5)|12 = 0x10AC
        b[8] = 0x10; b[9] = 0xAC
        // Product code 0x4081 → bytes 10-11 little-endian
        b[10] = 0x81; b[11] = 0x40
        // Serial 0x12345678 → bytes 12-15 little-endian
        b[12] = 0x78; b[13] = 0x56; b[14] = 0x34; b[15] = 0x12
        // Week 25, year 2012 (= 22 + 1990)
        b[16] = 25; b[17] = 22
        // EDID version 1, revision 4
        b[18] = 1; b[19] = 4
        // Descriptor block #2 at offset 72: display name (0xFC) "TestMon"
        b[72] = 0; b[73] = 0; b[74] = 0; b[75] = 0xFC; b[76] = 0
        let dispName = Array("TestMon\n".utf8)
        for (i, c) in dispName.enumerated() where i < 13 { b[77 + i] = c }
        for i in (77 + dispName.count)..<90 { b[i] = 0x20 } // pad with spaces
        // Descriptor block #3 at offset 90: serial string (0xFF) "ABC123"
        b[90] = 0; b[91] = 0; b[92] = 0; b[93] = 0xFF; b[94] = 0
        let ser = Array("ABC123\n".utf8)
        for (i, c) in ser.enumerated() where i < 13 { b[95 + i] = c }
        for i in (95 + ser.count)..<108 { b[i] = 0x20 }
        // Checksum at byte 127 — sum of all bytes mod 256 must be 0
        let sum: UInt32 = b[0..<127].reduce(0) { $0 + UInt32($1) }
        b[127] = UInt8((256 - Int(sum % 256)) % 256)
        return b
    }

    @Test("rejects bytes that do not begin with the EDID magic header")
    func rejectsBadHeader() {
        let bad = [UInt8](repeating: 0, count: 128)
        #expect(EDID.parse(bad) == nil)
    }

    @Test("rejects bytes shorter than 128")
    func rejectsShort() {
        let short = [UInt8](repeating: 0xFF, count: 127)
        #expect(EDID.parse(short) == nil)
    }

    @Test("rejects bytes with bad checksum")
    func rejectsBadChecksum() {
        var b = Self.sample()
        b[127] = b[127] &+ 1 // corrupt checksum
        #expect(EDID.parse(b) == nil)
    }

    @Test("parses manufacturer ID from packed 5-bit triplet")
    func parsesManufacturer() {
        let edid = EDID.parse(Self.sample())
        #expect(edid?.manufacturerID == "DEL")
    }

    @Test("parses product code little-endian")
    func parsesProductCode() {
        let edid = EDID.parse(Self.sample())
        #expect(edid?.productCode == 0x4081)
    }

    @Test("parses 32-bit serial number little-endian")
    func parsesSerial() {
        let edid = EDID.parse(Self.sample())
        #expect(edid?.serialNumber == 0x12345678)
    }

    @Test("parses week and year (year = byte17 + 1990)")
    func parsesDate() {
        let edid = EDID.parse(Self.sample())
        #expect(edid?.manufactureWeek == 25)
        #expect(edid?.manufactureYear == 2012)
    }

    @Test("parses EDID version + revision")
    func parsesVersion() {
        let edid = EDID.parse(Self.sample())
        #expect(edid?.edidVersion == "1.4")
    }

    @Test("parses display name from 0xFC descriptor block")
    func parsesDisplayName() {
        let edid = EDID.parse(Self.sample())
        #expect(edid?.displayName == "TestMon")
    }

    @Test("parses serial string from 0xFF descriptor block")
    func parsesSerialString() {
        let edid = EDID.parse(Self.sample())
        #expect(edid?.serialString == "ABC123")
    }

    @Test("stableID is deterministic and identical for same identity")
    func stableIDDeterministic() {
        let a = EDID.parse(Self.sample())!
        let b = EDID.parse(Self.sample())!
        #expect(a.stableID == b.stableID)
        #expect(a.stableID.count == 16)
        #expect(a.stableID.allSatisfy { $0.isHexDigit })
    }

    @Test("stableID changes when manufacturer/product/serial change")
    func stableIDIdentitySensitive() {
        var b = Self.sample()
        b[12] = 0x99 // mutate serial
        let sum: UInt32 = b[0..<127].reduce(0) { $0 + UInt32($1) }
        b[127] = UInt8((256 - Int(sum % 256)) % 256) // re-checksum
        let a = EDID.parse(Self.sample())!
        let m = EDID.parse(b)!
        #expect(a.stableID != m.stableID)
    }

    @Test("raw round-trip preserves bytes")
    func rawRoundtrip() {
        let bytes = Self.sample()
        let edid = EDID.parse(bytes)
        #expect(edid?.raw == bytes)
    }
}
