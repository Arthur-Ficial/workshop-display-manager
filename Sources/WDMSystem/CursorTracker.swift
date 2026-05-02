import Foundation
import AppKit
import CoreGraphics

/// Returns the `CGDirectDisplayID` containing the cursor right now. Recording
/// impl returns a fixed sequence for hermetic tests so `wdm follow` can be
/// e2e'd without a real cursor.
public protocol CursorTracker: Sendable {
    func currentDisplayID() -> UInt32?
}

public final class NSEventCursorTracker: CursorTracker, @unchecked Sendable {
    public init() {}
    public func currentDisplayID() -> UInt32? {
        let mouseLoc = NSEvent.mouseLocation
        // mouseLocation is in AppKit screen coords (bottom-left origin from
        // the primary display). Iterate NSScreen.screens — the one whose
        // .frame contains the point is the cursor's screen.
        for screen in NSScreen.screens {
            if NSPointInRect(mouseLoc, screen.frame) {
                return (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
            }
        }
        return nil
    }
}

public final class RecordingCursorTracker: CursorTracker, @unchecked Sendable {
    private let lock = NSLock()
    private var sequence: [UInt32]
    private var idx: Int = 0

    public init(sequence: [UInt32]) { self.sequence = sequence }

    public func currentDisplayID() -> UInt32? {
        lock.withLock {
            guard !sequence.isEmpty else { return nil }
            let v = sequence[idx % sequence.count]
            idx += 1
            return v
        }
    }
}
