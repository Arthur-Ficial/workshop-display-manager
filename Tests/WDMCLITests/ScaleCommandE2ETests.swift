import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm scale (e2e)")
struct ScaleCommandE2ETests {

    static func fixture() throws -> URL {
        let json = """
        {
          "snapshot": {
            "createdAt": 1700000000,
            "displays": [
              {
                "id": 1, "name": "4K External", "isMain": true, "isOnline": true,
                "mirrorSource": null,
                "currentMode": { "width": 3840, "height": 2160, "refreshHz": 60 },
                "origin": { "x": 0, "y": 0 },
                "rotationDegrees": 0
              }
            ]
          },
          "availableModes": {
            "1": [
              { "width": 3840, "height": 2160, "refreshHz": 60 },
              { "width": 2560, "height": 1440, "refreshHz": 60 },
              { "width": 1920, "height": 1200, "refreshHz": 60 },
              { "width": 1920, "height": 1080, "refreshHz": 60 },
              { "width": 1920, "height": 1080, "refreshHz": 30 }
            ]
          }
        }
        """
        return try CLITestHarness.makeFixture(json)
    }

    @Test("scale list prints every logical resolution available on the display")
    func scaleList() throws {
        let fx = try Self.fixture()
        let r = CLITestHarness.run(["scale", "1", "list"], fixture: fx)
        #expect(r.exitCode == 0)
        #expect(r.stdout.contains("3840x2160"))
        #expect(r.stdout.contains("2560x1440"))
        #expect(r.stdout.contains("1920x1200"))
        // 1920x1080 appears at two refresh rates but only one logical entry should print.
        let count = r.stdout.components(separatedBy: "1920x1080").count - 1
        #expect(count == 1)
    }

    @Test("scale <id> <WxH> applies the matching mode (any refresh)")
    func scaleApply() throws {
        let fx = try Self.fixture()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fx.path,
            "WDM_AUTO_CONFIRM": "1",
        ]
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let r = CLITestHarness.run(
            args: ["scale", "1", "1920x1200", "--no-confirm"],
            env: env, stdout: stdout, stderr: stderr
        )
        #expect(r == 0)
        // Verify post-state: the fixture should now show 1920x1200 as the current mode.
        let listed = CLITestHarness.run(["get", "1", "mode"], fixture: fx)
        #expect(listed.stdout.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("1920x1200"))
    }

    @Test("scale <id> looks-like <WxH> is an alias for the bare form")
    func scaleLooksLike() throws {
        let fx = try Self.fixture()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fx.path,
            "WDM_AUTO_CONFIRM": "1",
        ]
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let r = CLITestHarness.run(
            args: ["scale", "1", "looks-like", "2560x1440", "--no-confirm"],
            env: env, stdout: stdout, stderr: stderr
        )
        #expect(r == 0)
        let listed = CLITestHarness.run(["get", "1", "mode"], fixture: fx)
        #expect(listed.stdout.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("2560x1440"))
    }

    @Test("scale <id> <WxH> for an unsupported size exits 4")
    func scaleUnsupported() throws {
        let fx = try Self.fixture()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fx.path,
            "WDM_AUTO_CONFIRM": "1",
        ]
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let r = CLITestHarness.run(
            args: ["scale", "1", "1234x5678", "--no-confirm"],
            env: env, stdout: stdout, stderr: stderr
        )
        #expect(r == 4)
    }

    @Test("scale on unknown display exits 3")
    func scaleUnknown() throws {
        let fx = try Self.fixture()
        let r = CLITestHarness.run(["scale", "999", "list"], fixture: fx)
        #expect(r.exitCode == 3)
    }
}
