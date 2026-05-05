import Testing
import Foundation
@testable import WDMRemoteControl

/// Inspector GEOMETRY rotation + flip clicks must reach
/// `controller.rotate` / `controller.flip` and mutate the fixture's
/// state — proving the segments aren't no-op fakes (CLAUDE.md
/// "no fakes / no fallbacks" rule).
@Suite("wdm-mac headless: GEOMETRY rotation + flip clicks are real")
struct HeadlessGeometryTests {
    @Test func headlessTerminateDoesNotCrash() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        _ = try waitForPort(stateFile: env.stateFile)

        proc.terminate()
        proc.waitUntilExit()

        #expect(proc.terminationStatus != SIGTRAP,
                "wdm-mac trapped during SIGTERM shutdown")
    }

    @Test func clickingRotation180RotatesFixture() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        // Default selection is display 1 (Built-in). Click rotation 180.
        var snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let target = snap.nodes.first { $0.remoteID == "inspector.rotate.180" }
        try #require(target != nil, "inspector.rotate.180 must exist; got \(snap.nodes.map(\.remoteID).sorted())")

        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(target!.ref.rawValue)"}"#.utf8)
        let (_, resp) = try await URLSession.shared.data(for: click)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
        try await Task.sleep(nanoseconds: 300_000_000)

        // Fixture is the system of record.
        let bytes = try Data(contentsOf: env.fixture)
        let obj = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        let displays = (obj?["snapshot"] as? [String: Any])?["displays"] as? [[String: Any]]
        let builtIn = displays?.first { ($0["id"] as? Int) == 1 }
        let rot = builtIn?["rotationDegrees"] as? Int
        #expect(rot == 180,
                "expected rotation 180 after click; got \(String(describing: rot))")

        // Snapshot reflects the new selected segment too.
        snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let segment = snap.nodes.first { $0.remoteID == "inspector.rotate.180" }
        #expect(segment?.state.selected == true,
                "180 segment should be selected after click; state=\(String(describing: segment?.state))")
    }

    /// Flip uses the SOFTWARE OVERLAY path (`controller.flipOverlay`,
    /// same as `wdm flip-overlay`) — works on every Mac including
    /// Apple Silicon built-ins. The hermetic test asserts the
    /// `RecordingOverlayFlipper` was invoked with the expected axis
    /// by reading its log file.
    /// When the overlay flipper throws (e.g. Screen Recording permission
    /// denied), the GUI must surface the error visibly via
    /// `inspector.geometry.lastError`. Anything less is a fake — the
    /// user clicks Flip H, nothing flips, and they have no signal why.
    /// Regression: clicking flip then waiting must NOT crash the
    /// process. User reported app dying after each Flip H click; root
    /// cause was SCStream frame callbacks racing window-close. The
    /// fix detaches the frame sink's layer first + waits synchronously
    /// for stopCapture before tearing down. This test catches any
    /// future regression in that ordering.
    @Test func clickingFlipDoesNotCrashTheProcess() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        // Click flip once.
        let snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let target = snap.nodes.first { $0.remoteID == "inspector.flip.h" }
        try #require(target != nil)
        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(target!.ref.rawValue)"}"#.utf8)
        _ = try await URLSession.shared.data(for: click)

        // Wait past the flip's 600 ms duration + teardown grace. If the
        // process crashed, isPortAccepting returns false (the listener
        // is gone with the process) AND proc.isRunning becomes false.
        try await Task.sleep(nanoseconds: 1_500_000_000)
        #expect(proc.isRunning,
                "wdm-mac should still be running after a flip click; got dead")
        #expect(isPortAccepting(port: port),
                "port \(port) should still accept after a flip click; got connection refused")
    }

    @Test func flipFailureSurfacesAsLastErrorNode() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadlessWithFlipperThrow(env: env, message: "TEST: permission denied")
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        var snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let target = snap.nodes.first { $0.remoteID == "inspector.flip.h" }
        try #require(target != nil)

        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(target!.ref.rawValue)"}"#.utf8)
        _ = try await URLSession.shared.data(for: click)

        var errValue: String?
        for _ in 0..<25 {
            try await Task.sleep(nanoseconds: 80_000_000)
            snap = try SceneTreeJSON.decode(
                try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
            )
            errValue = snap.nodes.first { $0.remoteID == "inspector.geometry.lastError" }?.value
            if errValue?.contains("permission denied") == true { break }
        }
        #expect(errValue?.contains("permission denied") == true,
                "expected lastError to surface 'permission denied'; got \(String(describing: errValue))")
    }

    @Test func clickingFlipHInvokesOverlayFlipper() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        let snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let target = snap.nodes.first { $0.remoteID == "inspector.flip.h" }
        try #require(target != nil, "inspector.flip.h must exist")

        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(target!.ref.rawValue)"}"#.utf8)
        let (_, resp) = try await URLSession.shared.data(for: click)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)

        // The flipper runs on a detached Task and sleeps for 600 ms;
        // poll the log for up to 1.5 s.
        var content = ""
        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 50_000_000)
            content = (try? String(contentsOf: env.overlayLog, encoding: .utf8)) ?? ""
            if content.contains("displayID=1") && content.contains("horizontal") { break }
        }
        #expect(content.contains("displayID=1"),
                "overlay flipper log should record displayID=1; got \(content)")
        #expect(content.contains("horizontal"),
                "overlay flipper log should record horizontal axis; got \(content)")
    }
}
