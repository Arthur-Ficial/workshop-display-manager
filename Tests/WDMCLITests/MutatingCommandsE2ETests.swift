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

    @Test("unmirror clears the mirror relationship")
    func unmirror() throws {
        let fx = try CLITestHarness.makeFixture()
        _ = CLITestHarness.run(["mirror", "1", "2", "--no-confirm"], fixture: fx)
        let r = CLITestHarness.run(["unmirror", "2", "--no-confirm"], fixture: fx)
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
