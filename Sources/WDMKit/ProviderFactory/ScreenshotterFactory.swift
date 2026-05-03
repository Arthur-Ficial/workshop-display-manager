import Foundation
import WDMSystem

public enum ScreenshotterFactory {
    /// `WDM_TEST_SCREENSHOT_LOG` switches to the recording impl for hermetic
    /// tests; otherwise the real `screencapture`-backed one.
    public static func make(env: [String: String]) -> Screenshotter {
        if let path = env["WDM_TEST_SCREENSHOT_LOG"], !path.isEmpty {
            return RecordingScreenshotter(logURL: URL(fileURLWithPath: path))
        }
        return SCKScreenshotter()
    }
}
