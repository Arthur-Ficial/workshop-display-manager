import Foundation
import WDMCore

/// Software-backed virtual display manager. Real impl
/// (`CGVirtualDisplayManager`) talks to WindowServer via the `CGVirtualDisplay`
/// CoreGraphics SPI; the recording impl writes to a file for hermetic tests.
/// Lifetime is process-bound — the virtual display vanishes when `run`
/// returns.
public protocol VirtualDisplayManager: Sendable {
    /// Create the virtual display, block the calling thread until `stop()` is
    /// invoked from another thread or `durationMs` elapses, then tear it down.
    /// Throws on invalid spec or unavailable SPI.
    func run(spec: VirtualDisplaySpec, durationMs: Int?) throws

    /// Request `run` to return. Safe to call from any thread.
    func stop()
}
