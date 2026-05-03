import Foundation
import WDMSystem

public enum WindowMoverFactory {
    /// `WDM_TEST_WINDOW_MOVER_LOG` switches to the recording impl;
    /// otherwise the real AX-backed one.
    public static func make(env: [String: String]) -> WindowMover {
        if let p = env["WDM_TEST_WINDOW_MOVER_LOG"], !p.isEmpty {
            return RecordingWindowMover(logURL: URL(fileURLWithPath: p))
        }
        return AXWindowMover()
    }
}
