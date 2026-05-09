import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

/// 50 workshop-day scenarios a presenter can hit between "open laptop"
/// and "audience sees slides". Each `@Test` here either references an
/// existing covering test (in a `// covered:` comment) or is a RED test
/// for a current gap. Driving the gaps to GREEN is how we close out the
/// "issue #1" + workshop-reliability backlog.
@Suite("Workshop-day scenarios — 50 e2e checkpoints (catalog + RED gaps)")
struct WorkshopScenariosE2ETests {

    // ─────────────────────────────────────────────────────────────────────
    // PLUG-IN / CONNECTION (1–10)
    // ─────────────────────────────────────────────────────────────────────

    // 1. covered: plugging in HDMI projector → wdm sees new display
    //    → DisplayEvent + EventStream tests + wdm watch e2e.
    // 2. covered (real-hw): USB-C dock display chain enumerates
    //    → CGDisplayProviderSmokeTests under WDM_REAL_HARDWARE=1.
    // 3. GAP: AirPlay receiver virtual display appears — no fixture for it yet.
    // 4. GAP: Sidecar iPad virtual display appears — no fixture for it yet.
    // 5. GAP: two projectors via USB-C hub enumerate as distinct displays.
    // 6. GAP: cable connected but EDID handshake failed → display online, name nil.
    // 7. GAP: connected display reports unsupported preferred mode → fallback path.
    // 8. covered: re-plug of last-main display → `wdm restore last` reapplies
    //    → SaveRestoreE2ETests + auto-snapshot suite.
    // 9. RED below: rapid plug/unplug must NOT crash wdm itself.
    // 10. covered: plug-in matches saved auto-profile → DaemonE2ETests.

    // ─────────────────────────────────────────────────────────────────────
    // PROFILE MANAGEMENT (11–18)
    // ─────────────────────────────────────────────────────────────────────

    // 11. covered: save creates profile JSON → SaveRestoreE2ETests.
    // 12. covered: restore unknown profile → exit 6 → SaveRestoreE2ETests.
    // 13. RED below: restore against partially-present display set — must refuse cleanly,
    //     not partially apply.
    // 14. covered: save --auto keys by EDID → wdm save --auto suite.
    // 15. GAP: save with same name overwrites (or refuses, per design)
    //     — currently always overwrites silently; no test pinning that contract.
    // 16. covered: restore last after panic+reboot → AutoSnapshotTests + SaveRestoreE2ETests.
    // 17. covered: profiles list / --json → SaveRestoreE2ETests.
    // 18. GAP: `wdm profiles remove <name>` doesn't exist — RED below.

    // ─────────────────────────────────────────────────────────────────────
    // MODE / RESOLUTION (19–24)
    // ─────────────────────────────────────────────────────────────────────

    // 19. covered: unsupported mode → exit 4 → MutatingCommandsE2ETests.
    // 20. GAP: HiDPI vs LoDPI variants behave correctly → not yet exercised.
    // 21. covered (partial): mode listed but rejected by CG → MutatingCommandsE2ETests.
    // 22. covered: mode change with --confirm → SafetyTests + nativeConfirmer.
    // 23. covered: setMode to current is noChange → FixtureDisplayProviderTests.
    // 24. GAP: setMode on display in mirror group — undocumented behavior.

    // ─────────────────────────────────────────────────────────────────────
    // MIRROR (25–28)
    // ─────────────────────────────────────────────────────────────────────

    // 25. covered: mirror src→dst → MutatingCommandsE2ETests.
    // 26. GAP: mirror chain (A→B and B→C) — undefined; should reject or normalize.
    // 27. covered: unmirror noChange when not mirrored → FixtureDisplayProviderTests.
    // 28. GAP: mirror across resolutions — chooses smallest common, not asserted.

    // ─────────────────────────────────────────────────────────────────────
    // ROTATION / FLIP (29–33)
    // ─────────────────────────────────────────────────────────────────────

    // 29. covered: rotate on Apple Silicon w/o IODisplayConnect → exit 8 → CGRotateTests.
    // 30. covered (real-hw, gated): rotate on supported framebuffer → CGRotateRoundTripTests.
    // 31. covered (CLI surface): flip-overlay vertical → FlipOverlayE2ETests.
    //     Visually verified on this Mac with screenshot diff.
    // 32. covered: flip-overlay covers the target display → AppKitOverlayFlipper.
    // 33. covered: rotate+flip XOR composition → IOKitFlipEncodeTests.

    // ─────────────────────────────────────────────────────────────────────
    // BRIGHTNESS (34–36)
    // ─────────────────────────────────────────────────────────────────────

    // 34. covered: built-in brightness round-trip → BrightnessTests.
    // 35. covered: external monitor brightness → unsupported → BrightnessTests.
    // 36. covered: brightness out-of-range → exit 2 → BrightnessTests.

    // ─────────────────────────────────────────────────────────────────────
    // DAEMON (37–40)
    // ─────────────────────────────────────────────────────────────────────

    // 37. covered: daemon auto-restores on event → DaemonE2ETests.
    // 38. GAP: daemon LaunchAgent install — install-side asserted, load-side untested.
    // 39. GAP: daemon survives a restart cycle (real-hw, hard to test in CI).
    // 40. covered: daemon warns when no auto-profile matches → DaemonE2ETests.

    // ─────────────────────────────────────────────────────────────────────
    // WORKSHOP FLOW (41–45)
    // ─────────────────────────────────────────────────────────────────────

    // 41. covered: workshop start --audience N → WorkshopE2ETests.
    // 42. covered: workshop stop restores → WorkshopE2ETests.
    // 43. covered: workshop start with unknown audience id → exit 3 → WorkshopE2ETests.
    // 44. GAP: workshop start while already running — current behavior re-saves; pin it.
    // 45. covered: workshop stop without start → exit 6 → WorkshopE2ETests.

    // ─────────────────────────────────────────────────────────────────────
    // ISSUE #1 / PANIC RECOVERY (46–50)
    // ─────────────────────────────────────────────────────────────────────

    // 46. covered: wdm sleep invokes the sleeper → SleepCommandE2ETests.
    // 47. covered: post-reboot `wdm restore last` reapplies → AutoSnapshotTests.
    // 48. covered: last.json is written *before* mutation → SafeTransactionTests.
    // 49. covered: CG completion failure auto-reverts → SafeTransactionTests.
    // 50. RED below: hot-unplug mid-mutation must surface a typed error,
    //     not a half-applied state.

    // ─────────────────────────────────────────────────────────────────────
    // RED tests for the highest-priority gaps
    // ─────────────────────────────────────────────────────────────────────

    @Test("#9: rapid plug/unplug events don't crash wdm watch")
    func rapidPlugUnplugDoesNotCrash() async throws {
        let fx = try CLITestHarness.makeFixture()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-rapid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let evtFile = dir.appendingPathComponent("evts.jsonl")
        FileManager.default.createFile(atPath: evtFile.path, contents: nil)

        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fx.path,
            "WDM_TEST_EVENTS_FILE": evtFile.path,
        ]

        let producer = Task {
            try await Task.sleep(nanoseconds: 50_000_000)
            let h = try FileHandle(forWritingTo: evtFile)
            defer { try? h.close() }
            try h.seekToEnd()
            for i in 0..<20 {
                let kind: DisplayEvent.Kind = (i % 2 == 0) ? .added : .removed
                let e = DisplayEvent(timestamp: Date(), kind: kind, displayID: 7)
                try h.write(contentsOf: try JSONEncoder().encode(e))
                try h.write(contentsOf: Data("\n".utf8))
            }
        }

        let code = CLITestHarness.run(
            args: ["watch", "--json", "--max-events", "20"],
            env: env, stdout: stdout, stderr: stderr
        )
        _ = await producer.result
        #expect(code == 0)
        let lines = stdout.contents.split(separator: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 20)
    }

    @Test("#13: restore against partially-present display set exits 3 (display-not-found)")
    func partialRestoreFails() throws {
        let fx = try CLITestHarness.makeFixture()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-partial-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fx.path,
            "WDM_PROFILES_DIR": dir.path,
            "WDM_AUTO_CONFIRM": "1",
        ]
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()

        // Hand-roll a profile that mentions a display id (999) that isn't in the
        // current fixture. ProfileApplier must refuse instead of silently skipping.
        let profile = """
        {
          "createdAt": 1700000000,
          "displays": [
            {"id": 999, "name": "Ghost", "isMain": true, "isOnline": true,
             "mirrorSource": null,
             "currentMode": {"width": 1920, "height": 1080, "refreshHz": 60},
             "origin": {"x": 0, "y": 0}, "rotationDegrees": 0}
          ]
        }
        """
        try profile.write(
            to: dir.appendingPathComponent("ghost.json"),
            atomically: true, encoding: .utf8
        )

        let r = CLITestHarness.run(
            args: ["restore", "ghost"],
            env: env, stdout: stdout, stderr: stderr
        )
        #expect(r == ExitCodes.displayNotFound)
        #expect(stderr.contents.contains("999") || stderr.contents.contains("display"))
    }

    @Test("#18: `wdm profiles remove <name>` deletes the profile file")
    func profilesRemove() throws {
        let fx = try CLITestHarness.makeFixture()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-profiles-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fx.path,
            "WDM_PROFILES_DIR": dir.path,
            "WDM_AUTO_CONFIRM": "1",
        ]
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()

        // 1. Save a profile, verify it lists.
        _ = CLITestHarness.run(args: ["save", "demo"], env: env, stdout: stdout, stderr: stderr)
        let listed = CLITestHarness.run(args: ["profiles"], env: env, stdout: stdout, stderr: stderr)
        #expect(listed == 0)
        #expect(stdout.contents.contains("demo"))

        // 2. Remove it.
        let removed = CLITestHarness.run(args: ["profiles", "remove", "demo"], env: env, stdout: stdout, stderr: stderr)
        #expect(removed == 0)
        let path = dir.appendingPathComponent("demo.json").path
        #expect(!FileManager.default.fileExists(atPath: path))

        // 3. Removing again exits 6 (profile-not-found).
        let again = CLITestHarness.run(args: ["profiles", "remove", "demo"], env: env, stdout: stdout, stderr: stderr)
        #expect(again == ExitCodes.profileNotFound)
    }

    @Test("#50: hot-unplug mid-mutation surfaces exit 8 (CoreGraphicsError) without partial apply")
    func hotUnplugMidMutationSurfacesError() throws {
        let fx = try CLITestHarness.makeFixture()
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fx.path,
            "WDM_FIXTURE_FAIL_ROTATE": "1",
            "WDM_AUTO_CONFIRM": "1",
        ]
        let r = CLITestHarness.run(
            args: ["rotate", "2", "90", "--no-confirm"],
            env: env, stdout: stdout, stderr: stderr
        )
        #expect(r == ExitCodes.coreGraphicsError)
        #expect(stderr.contents.contains("hot-unplug") || stderr.contents.contains("mid-mutation"))

        // Verify no partial apply: rotation in fixture file is still 0.
        let after = CLITestHarness.run(
            args: ["get", "2", "rotation"],
            env: ["WDM_TEST_FIXTURE": fx.path],
            stdout: stdout, stderr: stderr
        )
        #expect(after == 0)
        #expect(stdout.contents.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("0"))
    }
}
