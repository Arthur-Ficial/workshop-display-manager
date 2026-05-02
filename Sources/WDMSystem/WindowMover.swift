import Foundation

/// Programmatically move the frontmost window of a matching app onto a
/// specific display. Real impl uses macOS Accessibility (AX) API
/// (`kAXPositionAttribute` + `kAXSizeAttribute`); recording impl logs the
/// call for hermetic e2e tests.
public protocol WindowMover: Sendable {
    /// Move the frontmost window of any running app whose name matches
    /// `pattern` (case-insensitive substring) onto `displayID`. The window
    /// is centered + sized to ~80% of the destination display.
    /// Throws `displayNotFound` if `displayID` is unknown,
    /// `configurationFailed` if Accessibility permission is missing.
    func move(pattern: String, displayID: UInt32) throws
}
