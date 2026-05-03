import Foundation
import WDMSystem

public enum CursorTrackerFactory {
    /// `WDM_TEST_CURSOR_SEQ=1,2,1` switches to a deterministic recording
    /// tracker that yields each id on each call (wrapping). Otherwise the
    /// real `NSEvent.mouseLocation`-backed tracker.
    public static func make(env: [String: String]) -> CursorTracker {
        if let s = env["WDM_TEST_CURSOR_SEQ"], !s.isEmpty {
            let seq = s.split(separator: ",").compactMap { UInt32($0) }
            if !seq.isEmpty {
                return RecordingCursorTracker(sequence: seq)
            }
        }
        return NSEventCursorTracker()
    }
}
