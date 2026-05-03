import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm edid (e2e)")
struct EDIDCommandE2ETests {

    /// A fixture that includes EDID blobs (base64 of the 128-byte block) per display.
    /// Display 1 = "Built-in" no EDID, display 2 = "Projector" with the test EDID.
    static func fixtureWithEDID() throws -> URL {
        let edidBytes = TestEDIDBytes.sample()
        let edidB64 = Data(edidBytes).base64EncodedString()
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
            "1": [{ "width": 2560, "height": 1664, "refreshHz": 60 }],
            "2": [{ "width": 1920, "height": 1080, "refreshHz": 60 }]
          },
          "edid": { "2": "\(edidB64)" }
        }
        """
        return try CLITestHarness.makeFixture(json)
    }

    @Test("edid <id> prints parsed manufacturer, product, year, name")
    func edidParsedHuman() throws {
        let fx = try Self.fixtureWithEDID()
        let r = CLITestHarness.run(["edid", "2"], fixture: fx)
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("DEL"))
        #expect(r.stdout.contains("0x4081"))
        #expect(r.stdout.contains("2012"))
        #expect(r.stdout.contains("TestMon"))
    }

    @Test("edid <id> --json prints structured JSON with stableID")
    func edidJSON() throws {
        let fx = try Self.fixtureWithEDID()
        let r = CLITestHarness.run(["edid", "2", "--json"], fixture: fx)
        #expect(r.exitCode == 0)
        let data = Data(r.stdout.utf8)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["manufacturerID"] as? String == "DEL")
        #expect((parsed?["productCode"] as? Int) == 0x4081)
        #expect((parsed?["manufactureYear"] as? Int) == 2012)
        #expect(parsed?["displayName"] as? String == "TestMon")
        let stable = parsed?["stableID"] as? String ?? ""
        #expect(stable.count == 16)
    }

    @Test("edid <id> --raw prints 128 bytes of hex")
    func edidRaw() throws {
        let fx = try Self.fixtureWithEDID()
        let r = CLITestHarness.run(["edid", "2", "--raw"], fixture: fx)
        #expect(r.exitCode == 0)
        // 128 bytes × 2 hex chars = 256 hex chars (whitespace allowed)
        let hexOnly = r.stdout.filter { $0.isHexDigit }
        #expect(hexOnly.count == 256)
        #expect(r.stdout.lowercased().hasPrefix("00ff") || r.stdout.lowercased().contains("00 ff"))
    }

    @Test("edid on a display without EDID exits 4 (modeNotSupported / unsupported)")
    func edidUnsupported() throws {
        let fx = try Self.fixtureWithEDID()
        let r = CLITestHarness.run(["edid", "1"], fixture: fx)
        #expect(r.exitCode == 4)
        #expect(r.stderr.lowercased().contains("edid") || r.stderr.lowercased().contains("unsupported"))
    }

    @Test("edid on unknown display exits 3")
    func edidUnknownDisplay() throws {
        let fx = try Self.fixtureWithEDID()
        let r = CLITestHarness.run(["edid", "999"], fixture: fx)
        #expect(r.exitCode == 3)
    }
}

/// Mirror of the EDIDTests sample EDID, redeclared here to avoid cross-target imports.
enum TestEDIDBytes {
    static func sample() -> [UInt8] {
        var b = [UInt8](repeating: 0, count: 128)
        b[0] = 0x00
        for i in 1...6 { b[i] = 0xFF }
        b[7] = 0x00
        b[8] = 0x10; b[9] = 0xAC
        b[10] = 0x81; b[11] = 0x40
        b[12] = 0x78; b[13] = 0x56; b[14] = 0x34; b[15] = 0x12
        b[16] = 25; b[17] = 22
        b[18] = 1; b[19] = 4
        b[72] = 0; b[73] = 0; b[74] = 0; b[75] = 0xFC; b[76] = 0
        let dispName = Array("TestMon\n".utf8)
        for (i, c) in dispName.enumerated() where i < 13 { b[77 + i] = c }
        for i in (77 + dispName.count)..<90 { b[i] = 0x20 }
        b[90] = 0; b[91] = 0; b[92] = 0; b[93] = 0xFF; b[94] = 0
        let ser = Array("ABC123\n".utf8)
        for (i, c) in ser.enumerated() where i < 13 { b[95 + i] = c }
        for i in (95 + ser.count)..<108 { b[i] = 0x20 }
        let sum: UInt32 = b[0..<127].reduce(0) { $0 + UInt32($1) }
        b[127] = UInt8((256 - Int(sum % 256)) % 256)
        return b
    }
}
