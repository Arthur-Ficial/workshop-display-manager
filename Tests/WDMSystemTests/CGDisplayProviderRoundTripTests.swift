import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

/// Aggressive real-hardware test: actually swaps the main display, verifies
/// the swap took effect via a fresh snapshot, swaps back, and verifies the
/// restoration matches the original snapshot. If anything fails between the
/// two swaps, the test forces a restoration to the original state.
///
/// Gated by `WDM_REAL_HARDWARE_MUTATE=1` — opt-in because it visibly moves
/// menu bar/dock between displays for ~1 second. Run with:
///
///   WDM_REAL_HARDWARE_MUTATE=1 swift test --filter CGDisplayProviderRoundTripTests
@Suite("CGDisplayProvider real round-trip (gated)",
       .enabled(if: ProcessInfo.processInfo.environment["WDM_REAL_HARDWARE_MUTATE"] == "1"))
struct CGDisplayProviderRoundTripTests {

    @Test("setMain swap-and-restore preserves original main")
    func swapAndRestore() throws {
        let provider = CGDisplayProvider()
        let before = try provider.snapshot()
        guard before.displays.count >= 2,
              let originalMain = before.main,
              let other = before.displays.first(where: { $0.id != originalMain.id })
        else {
            Issue.record("need at least 2 displays for round-trip test")
            return
        }

        defer {
            // Belt-and-suspenders: even on assertion failure, try to leave
            // the user's main where they had it.
            _ = try? provider.setMain(displayID: originalMain.id, options: .noConfirm)
        }

        let swap = try provider.setMain(displayID: other.id, options: .noConfirm)
        #expect(swap == .applied)
        let mid = try provider.snapshot()
        #expect(mid.main?.id == other.id, "main should now be \(other.id)")

        let restore = try provider.setMain(displayID: originalMain.id, options: .noConfirm)
        #expect(restore == .applied)
        let after = try provider.snapshot()
        #expect(after.main?.id == originalMain.id, "main should be restored")
    }
}
