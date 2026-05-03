import Foundation
import WDMSystem

public enum RecorderFactory {
    /// `WDM_TEST_RECORD_LOG` switches to the recording impl for hermetic
    /// tests; otherwise the real `screencapture -v`-backed one.
    public static func make(env: [String: String]) -> Recorder {
        if let path = env["WDM_TEST_RECORD_LOG"], !path.isEmpty {
            return RecordingRecorder(logURL: URL(fileURLWithPath: path))
        }
        return ScreenCaptureRecorder()
    }
}
