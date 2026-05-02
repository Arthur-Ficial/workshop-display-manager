import Foundation
import WDMSystem

public enum OverlayFlipperFactory {
    /// `WDM_TEST_OVERLAY_LOG` switches to the file-backed recording flipper for
    /// hermetic tests; otherwise the real AppKit/ScreenCaptureKit overlay.
    public static func make(env: [String: String]) -> OverlayFlipper {
        if let path = env["WDM_TEST_OVERLAY_LOG"], !path.isEmpty {
            return RecordingOverlayFlipper(url: URL(fileURLWithPath: path))
        }
        return AppKitOverlayFlipper()
    }
}
