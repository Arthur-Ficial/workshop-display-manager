import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm rename (e2e)")
struct RenameCommandE2ETests {

    static func setup() throws -> (URL, URL, [String: String]) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-rename-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let aliases = dir.appendingPathComponent("aliases.json")
        let overrides = dir.appendingPathComponent("Overrides")
        try FileManager.default.createDirectory(at: overrides, withIntermediateDirectories: true)
        let env: [String: String] = [
            "WDM_ALIASES_FILE": aliases.path,
            "WDM_OVERRIDES_DIR": overrides.path,
        ]
        return (aliases, overrides, env)
    }

    /// Fixture with EDID for display 2 so rename can derive a stable ID.
    static func fixture() throws -> URL {
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

    private static func runE2E(_ args: [String], env: [String: String], fixture: URL) -> CLIResult {
        var combined = env
        combined["WDM_TEST_FIXTURE"] = fixture.path
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let exit = CLITestHarness.run(args: args, env: combined, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: exit, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("rename <id> <name> writes an alias keyed by the display's stable EDID id")
    func writeAlias() throws {
        let fx = try Self.fixture()
        let (aliasFile, _, env) = try Self.setup()
        let r = Self.runE2E(["rename", "2", "Stage Left"], env: env, fixture: fx)
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: aliasFile, encoding: .utf8)
        #expect(body.contains("Stage Left"))
    }

    @Test("rename <id> <name> overrides the name shown in `wdm list`")
    func aliasShowsInList() throws {
        let fx = try Self.fixture()
        let (_, _, env) = try Self.setup()
        _ = Self.runE2E(["rename", "2", "Stage Left"], env: env, fixture: fx)
        let listed = Self.runE2E(["list"], env: env, fixture: fx)
        #expect(listed.exitCode == 0)
        #expect(listed.stdout.contains("Stage Left"))
    }

    @Test("rename --remove drops an alias; missing one exits 6")
    func removeAlias() throws {
        let fx = try Self.fixture()
        let (_, _, env) = try Self.setup()
        _ = Self.runE2E(["rename", "2", "Stage Left"], env: env, fixture: fx)
        let r1 = Self.runE2E(["rename", "2", "--remove"], env: env, fixture: fx)
        #expect(r1.exitCode == 0)
        let listed = Self.runE2E(["list"], env: env, fixture: fx)
        #expect(!listed.stdout.contains("Stage Left"))
        let r2 = Self.runE2E(["rename", "2", "--remove"], env: env, fixture: fx)
        #expect(r2.exitCode == 6)
    }

    @Test("rename --system writes an override plist with DisplayProductName")
    func systemOverridePlist() throws {
        let fx = try Self.fixture()
        let (_, overrides, env) = try Self.setup()
        let r = Self.runE2E(
            ["rename", "2", "Stage Left", "--system"], env: env, fixture: fx
        )
        #expect(r.exitCode == 0)
        // The override path is keyed by the display's vendor+product ID.
        // Sample EDID has manufacturer "DEL" → vendor 0x10AC; product 0x4081.
        let vendorDir = overrides.appendingPathComponent("DisplayVendorID-10ac")
        let plist = vendorDir.appendingPathComponent("DisplayProductID-4081")
        #expect(FileManager.default.fileExists(atPath: plist.path))
        let body = try String(contentsOf: plist, encoding: .utf8)
        #expect(body.contains("DisplayProductName"))
        #expect(body.contains("Stage Left"))
    }

    @Test("rename on a display without EDID falls back to id-keyed alias")
    func aliasWithoutEDID() throws {
        let fx = try Self.fixture()
        let (aliasFile, _, env) = try Self.setup()
        // Display 1 has no EDID in the fixture — must still get an alias.
        let r = Self.runE2E(["rename", "1", "Desk Mac"], env: env, fixture: fx)
        #expect(r.exitCode == 0)
        let body = try String(contentsOf: aliasFile, encoding: .utf8)
        #expect(body.contains("Desk Mac"))
        let listed = Self.runE2E(["list"], env: env, fixture: fx)
        #expect(listed.stdout.contains("Desk Mac"))
    }

    @Test("rename on unknown display exits 3")
    func renameUnknown() throws {
        let fx = try Self.fixture()
        let (_, _, env) = try Self.setup()
        let r = Self.runE2E(["rename", "999", "X"], env: env, fixture: fx)
        #expect(r.exitCode == 3)
    }
}
