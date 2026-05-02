import Foundation
import WDMSystem

public enum PipFlipperFactory {
    /// `WDM_TEST_PIP_LOG` switches to the file-backed recording flipper for
    /// hermetic tests; otherwise the real AppKit / ScreenCaptureKit PIP window.
    public static func make(env: [String: String]) -> PipFlipper {
        if let path = env["WDM_TEST_PIP_LOG"], !path.isEmpty {
            return RecordingPipFlipper(url: URL(fileURLWithPath: path))
        }
        return AppKitPipFlipper()
    }
}
