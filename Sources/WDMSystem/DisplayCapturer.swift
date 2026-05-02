import Foundation
import WDMCore

/// Soft-disconnect a display by acquiring an exclusive `CGDisplayCapture` on
/// it. The display blanks and other apps stop drawing to it; releasing the
/// capture (or the process exiting) brings it straight back online without
/// touching the cable. This is the only public-API path on macOS for an
/// on-the-fly disconnect/reconnect — `CGSSetDisplayConnected` and friends
/// are private and version-fragile, so we don't ship them.
public protocol DisplayCapturer: Sendable {
    func capture(_ id: UInt32) throws
    func release(_ id: UInt32) throws
}
