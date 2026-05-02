import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

@Suite("CGVirtualDisplayManager (unit)")
struct CGVirtualDisplayManagerTests {

    @Test("rejects spec with non-positive width")
    func rejectsZeroWidth() throws {
        let mgr = CGVirtualDisplayManager(isSPIAvailable: { true })
        let bad = VirtualDisplaySpec(
            name: "bad", width: 0, height: 1080, refreshHz: 60,
            hiDPI: true, widthMM: 600, heightMM: 340
        )
        #expect(throws: ProviderError.self) {
            try mgr.run(spec: bad, durationMs: 50)
        }
    }

    @Test("rejects spec with non-positive height")
    func rejectsZeroHeight() throws {
        let mgr = CGVirtualDisplayManager(isSPIAvailable: { true })
        let bad = VirtualDisplaySpec(
            name: "bad", width: 1920, height: 0, refreshHz: 60,
            hiDPI: true, widthMM: 600, heightMM: 340
        )
        #expect(throws: ProviderError.self) {
            try mgr.run(spec: bad, durationMs: 50)
        }
    }

    @Test("rejects spec with non-positive refreshHz")
    func rejectsZeroRefresh() throws {
        let mgr = CGVirtualDisplayManager(isSPIAvailable: { true })
        let bad = VirtualDisplaySpec(
            name: "bad", width: 1920, height: 1080, refreshHz: 0,
            hiDPI: true, widthMM: 600, heightMM: 340
        )
        #expect(throws: ProviderError.self) {
            try mgr.run(spec: bad, durationMs: 50)
        }
    }

    @Test("refuses honestly when SPI is unavailable (probe returns false)")
    func refusesWhenSPIMissing() throws {
        let mgr = CGVirtualDisplayManager(isSPIAvailable: { false })
        let spec = VirtualDisplaySpec.defaultSpec(name: "irrelevant")
        do {
            try mgr.run(spec: spec, durationMs: 50)
            Issue.record("expected throw when SPI unavailable")
        } catch let error as ProviderError {
            if case .configurationFailed(let msg) = error {
                #expect(msg.contains("CGVirtualDisplay") || msg.lowercased().contains("not available"))
            } else {
                Issue.record("expected configurationFailed, got \(error)")
            }
        }
    }
}
