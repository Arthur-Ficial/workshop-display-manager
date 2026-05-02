import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

/// Real-hardware smoke test for CGDisplayProvider read operations.
/// Only runs when WDM_REAL_HARDWARE=1 to keep `swift test` hermetic by default.
@Suite("CGDisplayProvider (real hardware, gated)",
       .enabled(if: ProcessInfo.processInfo.environment["WDM_REAL_HARDWARE"] == "1"))
struct CGDisplayProviderSmokeTests {

    @Test("snapshot returns at least one online display with a main")
    func snapshotHasMain() throws {
        let provider = CGDisplayProvider()
        let snap = try provider.snapshot()
        #expect(snap.displays.isEmpty == false, "expected at least one display")
        #expect(snap.main != nil, "expected one display to be main")
    }

    @Test("modes(for:) of main display is non-empty")
    func mainHasModes() throws {
        let provider = CGDisplayProvider()
        let snap = try provider.snapshot()
        guard let main = snap.main else {
            Issue.record("no main display"); return
        }
        let modes = try provider.modes(for: main.id)
        #expect(modes.isEmpty == false)
        #expect(modes.contains(main.currentMode), "current mode must be in modes list")
    }
}
