import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

@Suite("CGDisplayProvider real rotate (gated, idempotent)",
       .enabled(if: ProcessInfo.processInfo.environment["WDM_REAL_HARDWARE"] == "1"))
struct CGRotateTests {

    @Test("rotate to current rotation returns .noChange (no-op exercise of IOKit lookup)")
    func rotateNoChange() throws {
        let provider = CGDisplayProvider()
        let snap = try provider.snapshot()
        for d in snap.displays {
            let result = try provider.rotate(displayID: d.id, degrees: d.rotationDegrees, options: .noConfirm)
            #expect(result == .noChange)
        }
    }

    @Test("rotate to invalid degrees throws")
    func rotateInvalid() throws {
        let provider = CGDisplayProvider()
        let mainID = try provider.snapshot().main!.id
        #expect(throws: ProviderError.invalidRotation(45)) {
            _ = try provider.rotate(displayID: mainID, degrees: 45, options: .noConfirm)
        }
    }
}

@Suite("CGDisplayProvider real rotate round-trip (gated)",
       .enabled(if: ProcessInfo.processInfo.environment["WDM_REAL_HARDWARE_ROTATE"] == "1"))
struct CGRotateRoundTripTests {

    @Test("rotate either applies cleanly or throws the Apple Silicon limitation error")
    func rotateOrAppleSiliconFallback() throws {
        let provider = CGDisplayProvider()
        let snap = try provider.snapshot()
        guard let target = snap.displays.first(where: { !$0.isMain }) else {
            Issue.record("no external display to rotate")
            return
        }
        let original = target.rotationDegrees
        defer { _ = try? provider.rotate(displayID: target.id, degrees: original, options: .noConfirm) }

        let next = original == 0 ? 90 : 0

        if IOKitRotation.isSupported {
            let result = try provider.rotate(displayID: target.id, degrees: next, options: .noConfirm)
            #expect(result == .applied || result == .noChange)
            Thread.sleep(forTimeInterval: 1.0)
            let after = try provider.snapshot().display(id: target.id)?.rotationDegrees
            #expect(after == next || after == original)
        } else {
            // Apple Silicon: rotate must throw a clear, user-facing error pointing
            // at System Settings. We treat that as the documented contract.
            do {
                _ = try provider.rotate(displayID: target.id, degrees: next, options: .noConfirm)
                Issue.record("expected rotate to throw on Apple Silicon (no IODisplayConnect)")
            } catch let error as ProviderError {
                if case .configurationFailed(let msg) = error {
                    #expect(msg.contains("Apple Silicon") || msg.contains("System Settings"),
                            "error must explain the Apple Silicon limitation, got: \(msg)")
                } else {
                    Issue.record("expected configurationFailed, got \(error)")
                }
            }
        }
    }
}
