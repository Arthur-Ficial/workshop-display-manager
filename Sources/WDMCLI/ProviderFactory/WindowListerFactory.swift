import Foundation
import WDMSystem

public enum WindowListerFactory {
    /// `WDM_TEST_WINDOW_LISTER=1` switches to the recording (deterministic)
    /// impl for hermetic tests; otherwise the real `CGWindowListCopyWindowInfo`-backed one.
    public static func make(env: [String: String]) -> WindowLister {
        if (env["WDM_TEST_WINDOW_LISTER"] ?? "") == "1" {
            return RecordingWindowLister()
        }
        return CGWindowLister()
    }
}
