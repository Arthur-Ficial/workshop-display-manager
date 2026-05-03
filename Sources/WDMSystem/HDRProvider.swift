import Foundation

/// Toggle HDR on a display. Two impls:
///   - `CoreDisplayHDRProvider` (real, dlsym'd CoreDisplay SPI)
///   - `RecordingHDRProvider` (test, fixture map + log file)
public protocol HDRProvider: Sendable {
    /// Returns `true`/`false` for an HDR-capable display, `nil` for displays
    /// that don't support HDR at all (caller should refuse with exit 4).
    func isHDREnabled(displayID: UInt32) throws -> Bool?

    /// Toggle HDR on `displayID`. Throws `unsupported` for displays that
    /// don't expose the feature.
    func setHDR(displayID: UInt32, enabled: Bool) throws
}

public enum HDRError: Error, Equatable, Sendable {
    case unsupported(UInt32)
    case ioFailure(String)
}
