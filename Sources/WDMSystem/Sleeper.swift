import Foundation

/// Puts the Mac to sleep. The workshop use case is to drain `AppleHPM`'s
/// USB-C / DisplayPort-AltMode handshake queue *before* unplugging a
/// projector cable, sidestepping the Apple kernel-panic bug filed in
/// `Arthur-Ficial/workshop-display-manager#1`. Real impl uses the public
/// `IOPMSleepSystem` IOKit API; tests use a recording impl.
public protocol Sleeper: Sendable {
    /// Synchronously request immediate system sleep. Returns when the request
    /// has been issued — the actual sleep happens shortly after as the OS
    /// completes power-state transitions. Throws on hardware refusal.
    func sleepNow() throws
}
