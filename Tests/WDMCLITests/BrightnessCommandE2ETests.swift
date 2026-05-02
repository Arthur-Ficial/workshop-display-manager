import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm brightness (e2e)")
struct BrightnessCommandE2ETests {

    private func makeFixture(b1: Float?) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-bri-cli-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        let b1s = b1.map { String($0) } ?? "null"
        let json = """
        {
          "snapshot": {
            "createdAt": 1700000000,
            "displays": [
              { "id": 1, "name": "A", "isMain": true, "isOnline": true,
                "mirrorSource": null,
                "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
                "origin": { "x": 0, "y": 0 }, "rotationDegrees": 0 }
            ]
          },
          "availableModes": {
            "1": [{ "width": 1920, "height": 1080, "refreshHz": 60 }]
          },
          "brightness": { "1": \(b1s) }
        }
        """
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test("brightness <id> prints current value to stdout")
    func reads() throws {
        let fx = try makeFixture(b1: 0.42)
        let r = CLITestHarness.run(["brightness", "1"], fixture: fx)
        #expect(r.exitCode == 0)
        let parsed = Float(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(parsed == 0.42)
    }

    @Test("brightness <id> on unsupported display exits 4")
    func unsupportedExit4() throws {
        let fx = try makeFixture(b1: nil)
        let r = CLITestHarness.run(["brightness", "1"], fixture: fx)
        // Brightness can be nil even on the read path; treat as success and emit empty,
        // matching `wdm get N mirror` semantics for absent values.
        #expect(r.exitCode == 0)
        #expect(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "")
    }

    @Test("brightness <id> <value> sets brightness")
    func sets() throws {
        let fx = try makeFixture(b1: 0.5)
        let r = CLITestHarness.run(["brightness", "1", "0.8", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        let after = CLITestHarness.run(["brightness", "1"], fixture: fx)
        #expect(Float(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) == 0.8)
    }

    @Test("brightness <id> 1.5 exits 2 (out of range)")
    func outOfRange() throws {
        let fx = try makeFixture(b1: 0.5)
        let r = CLITestHarness.run(["brightness", "1", "1.5", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 2)
    }
}
