import Testing
import Foundation
import CoreGraphics
@testable import WDMCore
@testable import WDMSystem

/// Real-hardware smoke test for `CGVirtualDisplayManager`. Verifies that
/// the SPI actually creates a display visible to public CG enumeration on
/// THIS machine (macOS 26.x, Apple Silicon), and that the display vanishes
/// when the manager returns. Gated by `WDM_REAL_HARDWARE=1` to keep
/// `swift test` hermetic by default.
@Suite("CGVirtualDisplayManager (real hardware, gated)",
       .enabled(if: ProcessInfo.processInfo.environment["WDM_REAL_HARDWARE"] == "1"))
struct CGVirtualDisplayManagerSmokeTests {

    private func activeDisplayCount() -> UInt32 {
        var n: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &n)
        return n
    }

    private func activeDisplayIDs() -> [CGDirectDisplayID] {
        let n = activeDisplayCount()
        var ids = Array<CGDirectDisplayID>(repeating: 0, count: Int(n))
        var count: UInt32 = n
        CGGetActiveDisplayList(n, &ids, &count)
        return ids
    }

    @Test("creates a virtual display that appears in CGGetActiveDisplayList, then tears it down")
    func roundTrip() async throws {
        let baseline = activeDisplayCount()
        let mgr = CGVirtualDisplayManager()
        let spec = VirtualDisplaySpec(
            name: "wdm smoke", width: 1920, height: 1080, refreshHz: 60,
            hiDPI: true, widthMM: 600, heightMM: 340
        )

        // Run the manager in a detached task with a 1.5s lifetime; while it's
        // alive, poll the active-display list and assert the count grew by 1.
        let task = Task.detached {
            try mgr.run(spec: spec, durationMs: 1500)
        }

        // Poll up to 1s for the new display to register.
        var grew = false
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 50_000_000)
            if activeDisplayCount() == baseline + 1 { grew = true; break }
        }
        #expect(grew, "active display count did not grow within 1s of CGVirtualDisplayManager.run")

        _ = try await task.value

        // After teardown the count should drop back. Allow a brief settle.
        var settled = false
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 50_000_000)
            if activeDisplayCount() == baseline { settled = true; break }
        }
        #expect(settled, "active display count did not return to baseline within 1s of teardown")
    }
}
