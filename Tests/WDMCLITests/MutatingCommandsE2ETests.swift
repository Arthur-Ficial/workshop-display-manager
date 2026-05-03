import Testing
import Foundation
@testable import WDMCLI

@Suite("wdm mutating commands (e2e)")
struct MutatingCommandsE2ETests {

    @Test("mode <id> <WxH@Hz> sets the display mode")
    func setMode() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["mode", "2", "1280x720@60", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        let after = CLITestHarness.run(["get", "2", "mode"], fixture: fx)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1280x720@60")
    }

    @Test("mode rejects unsupported mode with exit 4")
    func setModeUnsupported() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["mode", "2", "9999x9999@60", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 4)
    }

    @Test("main <id> sets the primary display")
    func setMain() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["main", "2", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        let after = CLITestHarness.run(["get", "main", "id"], fixture: fx)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "2")
    }

    @Test("mirror src dst makes dst mirror src")
    func mirror() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["mirror", "1", "2", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        let after = CLITestHarness.run(["get", "2", "mirror"], fixture: fx)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }

    @Test("mirror src dst1 dst2 mirrors source onto BOTH targets at once")
    func mirrorMulti() throws {
        let fx = try CLITestHarness.makeFixture(threeDisplayFixture)
        let r = CLITestHarness.run(["mirror", "1", "2", "3", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        let m2 = CLITestHarness.run(["get", "2", "mirror"], fixture: fx)
        #expect(m2.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
        let m3 = CLITestHarness.run(["get", "3", "mirror"], fixture: fx)
        #expect(m3.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }

    @Test("mirror with three targets — source mirrors to all of them")
    func mirrorThreeTargets() throws {
        let fx = try CLITestHarness.makeFixture(fourDisplayFixture)
        let r = CLITestHarness.run(["mirror", "1", "2", "3", "4", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        for tgt in ["2", "3", "4"] {
            let g = CLITestHarness.run(["get", tgt, "mirror"], fixture: fx)
            #expect(g.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
        }
    }

    @Test("mirror unknown target exits 3 and atomically applies nothing")
    func mirrorUnknownAtomic() throws {
        let fx = try CLITestHarness.makeFixture(threeDisplayFixture)
        let r = CLITestHarness.run(["mirror", "1", "2", "999", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 3)
        // Display 2 should NOT be mirroring after the failed call.
        let after = CLITestHarness.run(["get", "2", "mirror"], fixture: fx)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "")
    }

    @Test("mirror without dst exits 2")
    func mirrorMissingDst() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["mirror", "1", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 2)
    }

    private var threeDisplayFixture: String {
        """
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
              },
              {
                "id": 3, "name": "Stage Right", "isMain": false, "isOnline": true,
                "mirrorSource": null,
                "currentMode": { "width": 1280, "height": 720, "refreshHz": 60 },
                "origin": { "x": 4480, "y": 0 },
                "rotationDegrees": 0
              }
            ]
          },
          "availableModes": {
            "1": [{ "width": 2560, "height": 1664, "refreshHz": 60 }],
            "2": [{ "width": 1920, "height": 1080, "refreshHz": 60 }],
            "3": [{ "width": 1280, "height": 720,  "refreshHz": 60 }]
          }
        }
        """
    }

    private var fourDisplayFixture: String {
        """
        {
          "snapshot": {
            "createdAt": 1700000000,
            "displays": [
              { "id": 1, "name": "A", "isMain": true,  "isOnline": true,
                "mirrorSource": null,
                "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
                "origin": { "x": 0, "y": 0 }, "rotationDegrees": 0 },
              { "id": 2, "name": "B", "isMain": false, "isOnline": true,
                "mirrorSource": null,
                "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
                "origin": { "x": 1920, "y": 0 }, "rotationDegrees": 0 },
              { "id": 3, "name": "C", "isMain": false, "isOnline": true,
                "mirrorSource": null,
                "currentMode": { "width": 1280, "height": 720, "refreshHz": 60 },
                "origin": { "x": 3840, "y": 0 }, "rotationDegrees": 0 },
              { "id": 4, "name": "D", "isMain": false, "isOnline": true,
                "mirrorSource": null,
                "currentMode": { "width": 1024, "height": 768, "refreshHz": 60 },
                "origin": { "x": 5120, "y": 0 }, "rotationDegrees": 0 }
            ]
          },
          "availableModes": {
            "1": [{ "width": 1920, "height": 1080, "refreshHz": 60 }],
            "2": [{ "width": 1920, "height": 1080, "refreshHz": 60 }],
            "3": [{ "width": 1280, "height": 720,  "refreshHz": 60 }],
            "4": [{ "width": 1024, "height": 768,  "refreshHz": 60 }]
          }
        }
        """
    }

    @Test("unmirror clears the mirror relationship")
    func unmirror() throws {
        let fx = try CLITestHarness.makeFixture()
        _ = CLITestHarness.run(["mirror", "1", "2", "--no-confirm"], fixture: fx)
        let r = CLITestHarness.run(["unmirror", "2", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        let after = CLITestHarness.run(["get", "2", "mirror"], fixture: fx)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "")
    }

    @Test("unmirror <masterID> breaks the whole mirror group (issue #2)")
    func unmirrorByMaster() throws {
        let fx = try CLITestHarness.makeFixture()
        _ = CLITestHarness.run(["mirror", "1", "2", "--no-confirm"], fixture: fx)
        let r = CLITestHarness.run(["unmirror", "1", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        let after = CLITestHarness.run(["get", "2", "mirror"], fixture: fx)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "")
    }

    @Test("move <id> x y updates origin")
    func move() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["move", "2", "-1920", "0", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        let after = CLITestHarness.run(["get", "2", "origin"], fixture: fx)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "-1920,0")
    }

    @Test("rotate <id> 90 sets rotation")
    func rotate() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["rotate", "2", "90", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        let after = CLITestHarness.run(["get", "2", "rotation"], fixture: fx)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "90")
    }

    @Test("rotate rejects 45 with usage exit code")
    func rotateInvalid() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["rotate", "2", "45", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 2)
    }

    @Test("flip <id> vertical sets vertical flip")
    func flipVertical() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["flip", "2", "vertical", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
    }

    @Test("flip <id> horizontal sets horizontal flip; off clears it; idempotent")
    func flipHorizontalAndOff() throws {
        let fx = try CLITestHarness.makeFixture()
        var r = CLITestHarness.run(["flip", "2", "horizontal", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        // Setting again is idempotent at the provider level — CLI still exits 0.
        r = CLITestHarness.run(["flip", "2", "h", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        r = CLITestHarness.run(["flip", "2", "off", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
    }

    @Test("flip rejects unknown axis token with usage exit code")
    func flipInvalid() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["flip", "2", "diagonal", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 2)
    }

    @Test("flip on unknown display exits 3 (display-not-found)")
    func flipUnknownDisplay() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["flip", "999", "vertical", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 3)
    }

    @Test("switch swaps main between two displays")
    func switchMain() throws {
        let fx = try CLITestHarness.makeFixture()
        let r = CLITestHarness.run(["switch", "--no-confirm"], fixture: fx)
        #expect(r.exitCode == 0)
        let after = CLITestHarness.run(["get", "main", "id"], fixture: fx)
        #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "2")

        // switching again returns to original
        _ = CLITestHarness.run(["switch", "--no-confirm"], fixture: fx)
        let back = CLITestHarness.run(["get", "main", "id"], fixture: fx)
        #expect(back.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }

    @Test("cycle rotates main forward through all displays")
    func cycle() throws {
        let fx = try CLITestHarness.makeFixture()
        // Start: main = 1.  After one cycle: main = 2.
        _ = CLITestHarness.run(["cycle", "--no-confirm"], fixture: fx)
        let after1 = CLITestHarness.run(["get", "main", "id"], fixture: fx)
        #expect(after1.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "2")
        // After another cycle: main = 1 again (wraps).
        _ = CLITestHarness.run(["cycle", "--no-confirm"], fixture: fx)
        let after2 = CLITestHarness.run(["get", "main", "id"], fixture: fx)
        #expect(after2.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }
}
