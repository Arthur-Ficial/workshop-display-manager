import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

@Suite("CGDisplayProvider real flip (gated, idempotent)",
       .enabled(if: ProcessInfo.processInfo.environment["WDM_REAL_HARDWARE"] == "1"))
struct CGFlipTests {

    @Test("flip to current state returns .noChange (no IOKit write attempted)")
    func flipNoChange() throws {
        let provider = CGDisplayProvider()
        let snap = try provider.snapshot()
        for d in snap.displays {
            let current = try provider.flip(for: d.id)
            let result = try provider.setFlip(displayID: d.id, flip: current, options: .noConfirm)
            #expect(result == .noChange)
        }
    }
}

@Suite("CGDisplayProvider flip round-trip (gated, side-effecting)",
       .enabled(if: ProcessInfo.processInfo.environment["WDM_REAL_HARDWARE_FLIP"] == "1"))
struct CGFlipRoundTripTests {

    @Test("flip either applies cleanly or throws the Apple Silicon limitation error")
    func flipOrAppleSiliconFallback() throws {
        let provider = CGDisplayProvider()
        let snap = try provider.snapshot()
        guard let target = snap.displays.first(where: { !$0.isMain }) else {
            Issue.record("no external display to flip")
            return
        }
        let original = try provider.flip(for: target.id)
        defer { _ = try? provider.setFlip(displayID: target.id, flip: original, options: .noConfirm) }

        do {
            _ = try provider.setFlip(displayID: target.id, flip: .vertical, options: .noConfirm)
            Thread.sleep(forTimeInterval: 1.0)
            let after = try provider.flip(for: target.id)
            #expect(after == .vertical)
        } catch let error as ProviderError {
            // The honest-refusal branch — must mention the Apple Silicon limitation
            // so the user knows it's not a code bug.
            if case .configurationFailed(let msg) = error {
                #expect(msg.contains("Apple Silicon") || msg.contains("IOFramebuffer"),
                        "error must explain the unsupported-path reason, got: \(msg)")
            } else {
                Issue.record("expected configurationFailed, got \(error)")
            }
        }
    }
}
