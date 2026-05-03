import Foundation
import WDMSystem

public enum DisplayCapturerFactory {
    /// `WDM_TEST_CAPTURE_LOG` switches to the file-backed recording capturer
    /// for hermetic tests; otherwise the real `CGDisplayCapture`-backed one.
    public static func make(env: [String: String]) -> DisplayCapturer {
        if let path = env["WDM_TEST_CAPTURE_LOG"], !path.isEmpty {
            return RecordingDisplayCapturer(url: URL(fileURLWithPath: path))
        }
        return CGDisplayCapturer()
    }
}
