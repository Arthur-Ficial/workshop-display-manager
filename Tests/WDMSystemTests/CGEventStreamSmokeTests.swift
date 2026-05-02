import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

/// Real-hardware smoke test for CGDisplayEventStream.
/// Verifies that registering and tearing down the CG reconfiguration callback succeeds.
/// Gated by WDM_REAL_HARDWARE=1 to keep `swift test` hermetic by default.
@Suite("CGDisplayEventStream (real hardware, gated)",
       .enabled(if: ProcessInfo.processInfo.environment["WDM_REAL_HARDWARE"] == "1"))
struct CGEventStreamSmokeTests {

    @Test("can register and tear down the reconfiguration callback")
    func registerAndTeardown() async throws {
        let stream = CGDisplayEventStream()
        // Start consuming, then immediately cancel to exercise register + remove paths.
        let task = Task {
            for try await _ in stream.events.prefix(0) {
                // never reached — we ask for 0 events, the stream finishes immediately.
            }
        }
        // Allow the registration to happen, then cancel.
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        _ = await task.result
    }
}
