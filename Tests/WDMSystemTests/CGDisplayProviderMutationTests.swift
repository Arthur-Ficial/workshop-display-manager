import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

/// Real-hardware tests for CGDisplayProvider mutating ops.
/// Only idempotent ("set to current value") paths are exercised here so the
/// suite is safe to run on the developer's actual machine — they short-circuit
/// to .noChange and never touch the live display config. The full CG path is
/// verified by manual smoke (`wdm switch`).
@Suite("CGDisplayProvider mutations (real hardware, gated, idempotent)",
       .enabled(if: ProcessInfo.processInfo.environment["WDM_REAL_HARDWARE"] == "1"))
struct CGDisplayProviderMutationTests {

    @Test("setMain to current main returns .noChange")
    func setMainNoChange() throws {
        let provider = CGDisplayProvider()
        let snap = try provider.snapshot()
        let mainID = snap.main!.id
        let result = try provider.setMain(displayID: mainID, options: .noConfirm)
        #expect(result == .noChange)
    }

    @Test("setMode to current mode returns .noChange")
    func setModeNoChange() throws {
        let provider = CGDisplayProvider()
        let snap = try provider.snapshot()
        let d = snap.displays.first!
        let result = try provider.setMode(displayID: d.id, mode: d.currentMode, options: .noConfirm)
        #expect(result == .noChange)
    }

    @Test("move to current origin returns .noChange")
    func moveNoChange() throws {
        let provider = CGDisplayProvider()
        let snap = try provider.snapshot()
        let d = snap.displays.first!
        let result = try provider.move(displayID: d.id, to: d.origin, options: .noConfirm)
        #expect(result == .noChange)
    }

    @Test("setMain on unknown display throws displayNotFound")
    func setMainUnknown() throws {
        let provider = CGDisplayProvider()
        #expect(throws: ProviderError.displayNotFound(99999)) {
            _ = try provider.setMain(displayID: 99999, options: .noConfirm)
        }
    }

    @Test("setMode on unknown display throws displayNotFound")
    func setModeUnknown() throws {
        let provider = CGDisplayProvider()
        #expect(throws: ProviderError.displayNotFound(99999)) {
            _ = try provider.setMode(
                displayID: 99999,
                mode: Mode(width: 1920, height: 1080, refreshHz: 60),
                options: .noConfirm
            )
        }
    }
}
