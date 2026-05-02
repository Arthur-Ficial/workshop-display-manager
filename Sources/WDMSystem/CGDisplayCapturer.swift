import Foundation
import CoreGraphics

/// Real `DisplayCapturer` backed by `CGDisplayCapture` / `CGDisplayRelease`.
/// Public CoreGraphics API — no private symbols, no version-fragile shims.
public final class CGDisplayCapturer: DisplayCapturer {
    public init() {}

    public func capture(_ id: UInt32) throws {
        let err = CGDisplayCapture(CGDirectDisplayID(id))
        guard err == .success else {
            throw ProviderError.configurationFailed(
                "CGDisplayCapture(\(id)) failed: \(err.rawValue)"
            )
        }
    }

    public func release(_ id: UInt32) throws {
        let err = CGDisplayRelease(CGDirectDisplayID(id))
        guard err == .success else {
            throw ProviderError.configurationFailed(
                "CGDisplayRelease(\(id)) failed: \(err.rawValue)"
            )
        }
    }
}
