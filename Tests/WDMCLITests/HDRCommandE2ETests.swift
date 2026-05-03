import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm hdr (e2e)")
struct HDRCommandE2ETests {

    /// Fixture: display 1 = no HDR support; display 2 = HDR-capable, currently off.
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
                "id": 2, "name": "Pro Display XDR", "isMain": false, "isOnline": true,
                "mirrorSource": null,
                "currentMode": { "width": 6016, "height": 3384, "refreshHz": 60 },
                "origin": { "x": 2560, "y": 0 },
                "rotationDegrees": 0
              }
            ]
          },
          "availableModes": {
            "1": [{ "width": 2560, "height": 1664, "refreshHz": 60 }],
            "2": [{ "width": 6016, "height": 3384, "refreshHz": 60 }]
          },
          "hdr": { "2": false }
        }
        """
        return try CLITestHarness.makeFixture(json)
    }

    private static func runWithHDRLog(_ args: [String], fixture: URL) throws -> (CLIResult, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-hdr-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let log = dir.appendingPathComponent("hdr.log")
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_HDR_LOG": log.path,
        ]
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let exit = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return (CLIResult(exitCode: exit, stdout: stdout.contents, stderr: stderr.contents), log)
    }

    @Test("hdr <id> reads current state on an HDR-capable display")
    func readHDR() throws {
        let fx = try Self.fixture()
        let (r, _) = try Self.runWithHDRLog(["hdr", "2"], fixture: fx)
        #expect(r.exitCode == 0)
        #expect(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "off")
    }

    @Test("hdr <id> on enables HDR and records the write")
    func enableHDR() throws {
        let fx = try Self.fixture()
        let (r, log) = try Self.runWithHDRLog(["hdr", "2", "on"], fixture: fx)
        #expect(r.exitCode == 0)
        let body = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        #expect(body.contains("set display=2 hdr=on"))
        // Subsequent read picks up the new state.
        let (r2, _) = try Self.runWithHDRLog(["hdr", "2"], fixture: fx)
        #expect(r2.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "on")
    }

    @Test("hdr <id> off disables HDR and records the write")
    func disableHDR() throws {
        let fx = try Self.fixture()
        _ = try Self.runWithHDRLog(["hdr", "2", "on"], fixture: fx)
        let (r, log) = try Self.runWithHDRLog(["hdr", "2", "off"], fixture: fx)
        #expect(r.exitCode == 0)
        let body = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        #expect(body.contains("set display=2 hdr=off"))
    }

    @Test("hdr on a non-HDR display exits 4 with a clear message")
    func nonHDRDisplay() throws {
        let fx = try Self.fixture()
        let (r, _) = try Self.runWithHDRLog(["hdr", "1"], fixture: fx)
        #expect(r.exitCode == 4)
        #expect(r.stderr.lowercased().contains("hdr"))
    }

    @Test("hdr <id> bad-value exits 2")
    func badValue() throws {
        let fx = try Self.fixture()
        let (r, _) = try Self.runWithHDRLog(["hdr", "2", "kinda"], fixture: fx)
        #expect(r.exitCode == 2)
    }

    @Test("hdr on unknown display exits 3")
    func unknownDisplay() throws {
        let fx = try Self.fixture()
        let (r, _) = try Self.runWithHDRLog(["hdr", "999"], fixture: fx)
        #expect(r.exitCode == 3)
    }
}
