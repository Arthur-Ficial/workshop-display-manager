import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm ddc (e2e)")
struct DDCCommandE2ETests {

    /// Fixture with a DDC-capable display (id 2) and a non-DDC display (id 1).
    /// `ddc` map keys are display IDs; values are dictionaries of VCP-code →
    /// numeric value. The recording provider answers reads from this map and
    /// records writes to a log file (WDM_TEST_DDC_LOG).
    static func fixture() throws -> URL {
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
                "id": 2, "name": "DELL U2723QE", "isMain": false, "isOnline": true,
                "mirrorSource": null,
                "currentMode": { "width": 3840, "height": 2160, "refreshHz": 60 },
                "origin": { "x": 2560, "y": 0 },
                "rotationDegrees": 0
              }
            ]
          },
          "availableModes": {
            "1": [{ "width": 2560, "height": 1664, "refreshHz": 60 }],
            "2": [{ "width": 3840, "height": 2160, "refreshHz": 60 }]
          },
          "ddc": {
            "2": { "16": 50, "18": 75, "96": 17 }
          }
        }
        """
        return try CLITestHarness.makeFixture(json)
    }

    private static func runWithDDCLog(_ args: [String], fixture: URL) throws -> (CLIResult, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-ddc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let log = dir.appendingPathComponent("ddc.log")
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_DDC_LOG": log.path,
        ]
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let exit = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return (CLIResult(exitCode: exit, stdout: stdout.contents, stderr: stderr.contents), log)
    }

    @Test("ddc brightness <id> reads the current brightness in 0..1")
    func readBrightness() throws {
        let fx = try Self.fixture()
        let (r, _) = try Self.runWithDDCLog(["ddc", "brightness", "2"], fixture: fx)
        #expect(r.exitCode == 0)
        // Fixture VCP 0x10 = 50 → 0.5 (assuming 0..100 range)
        let value = Float(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
        #expect(abs(value - 0.5) < 0.01)
    }

    @Test("ddc brightness <id> <0..1> writes via I2C and records the call")
    func writeBrightness() throws {
        let fx = try Self.fixture()
        let (r, log) = try Self.runWithDDCLog(["ddc", "brightness", "2", "0.3"], fixture: fx)
        #expect(r.exitCode == 0)
        let body = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        // VCP 0x10 = 16; 0.3 × 100 = 30
        #expect(body.contains("write display=2 vcp=0x10 value=30"))
    }

    @Test("ddc contrast <id> reads + writes")
    func contrast() throws {
        let fx = try Self.fixture()
        let (r1, _) = try Self.runWithDDCLog(["ddc", "contrast", "2"], fixture: fx)
        #expect(r1.exitCode == 0)
        // Fixture VCP 0x12 = 75 → 0.75
        let v = Float(r1.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
        #expect(abs(v - 0.75) < 0.01)
        let (r2, log) = try Self.runWithDDCLog(["ddc", "contrast", "2", "0.6"], fixture: fx)
        #expect(r2.exitCode == 0)
        let body = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        #expect(body.contains("write display=2 vcp=0x12 value=60"))
    }

    @Test("ddc input <id> <name> writes VCP 0x60 with the right code")
    func inputSwitch() throws {
        let fx = try Self.fixture()
        let (r, log) = try Self.runWithDDCLog(["ddc", "input", "2", "hdmi1"], fixture: fx)
        #expect(r.exitCode == 0)
        let body = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        // VCP 0x60 = 96; "hdmi1" canonical code is 17 (0x11)
        #expect(body.contains("write display=2 vcp=0x60 value=17"))
    }

    @Test("ddc get <id> 0xNN reads a raw VCP code")
    func rawGet() throws {
        let fx = try Self.fixture()
        let (r, _) = try Self.runWithDDCLog(["ddc", "get", "2", "0x10"], fixture: fx)
        #expect(r.exitCode == 0)
        #expect(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "50")
    }

    @Test("ddc set <id> 0xNN <value> writes a raw VCP code")
    func rawSet() throws {
        let fx = try Self.fixture()
        let (r, log) = try Self.runWithDDCLog(["ddc", "set", "2", "0x10", "42"], fixture: fx)
        #expect(r.exitCode == 0)
        let body = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        #expect(body.contains("write display=2 vcp=0x10 value=42"))
    }

    @Test("ddc on a display that doesn't expose DDC exits 4")
    func ddcUnsupported() throws {
        let fx = try Self.fixture()
        let (r, _) = try Self.runWithDDCLog(["ddc", "brightness", "1"], fixture: fx)
        #expect(r.exitCode == 4)
        #expect(r.stderr.lowercased().contains("ddc"))
    }

    @Test("ddc on unknown display exits 3")
    func ddcUnknownDisplay() throws {
        let fx = try Self.fixture()
        let (r, _) = try Self.runWithDDCLog(["ddc", "brightness", "999"], fixture: fx)
        #expect(r.exitCode == 3)
    }

    @Test("ddc brightness out-of-range value exits 2")
    func ddcOutOfRange() throws {
        let fx = try Self.fixture()
        let (r, _) = try Self.runWithDDCLog(["ddc", "brightness", "2", "1.5"], fixture: fx)
        #expect(r.exitCode == 2)
    }
}
