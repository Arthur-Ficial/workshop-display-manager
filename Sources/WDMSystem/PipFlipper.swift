import Foundation
import WDMCore

/// Picture-in-picture display mirror. Captures `sourceID` and renders it
/// (optionally with a `flip` transform) into a movable, resizable window
/// that lives on `destinationID` (or wherever the user drags it).
///
/// Sibling of `OverlayFlipper`: same SCStream capture machinery, but the
/// window has a title bar and is not the screen-shielding overlay.
/// Workshop use-cases:
///   - presenter sees a flipped preview of the projector on their built-in;
///   - audience sees the slides while the speaker keeps a small mirror;
///   - "screen in screen" demos.
public protocol PipFlipper: Sendable {
    /// Open the PIP window. Blocks until `stop()` or `durationMs` elapses.
    /// Throws `displayNotFound` if either id is unknown.
    func run(
        sourceID: UInt32,
        destinationID: UInt32,
        size: PipSize,
        flip: Flip,
        durationMs: Int?
    ) throws

    func stop()
}

public struct PipSize: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// Parse `WxH` form (e.g. `"1280x720"`). Returns nil for any other input.
    public static func parse(_ token: String) -> PipSize? {
        let parts = token.split(separator: "x")
        guard parts.count == 2,
              let w = Int(parts[0]), w > 0,
              let h = Int(parts[1]), h > 0
        else { return nil }
        return PipSize(width: w, height: h)
    }

    /// Sane default for a workshop preview: ~720p, fits on most laptop screens.
    public static let defaultSize = PipSize(width: 1280, height: 720)
}
