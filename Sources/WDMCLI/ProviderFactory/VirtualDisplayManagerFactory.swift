import Foundation
import WDMSystem

public enum VirtualDisplayManagerFactory {
    /// `WDM_TEST_VIRTUAL_LOG` switches to the file-backed recording manager
    /// for hermetic tests; otherwise the real `CGVirtualDisplay`-backed one.
    public static func make(env: [String: String]) -> VirtualDisplayManager {
        if let path = env["WDM_TEST_VIRTUAL_LOG"], !path.isEmpty {
            return RecordingVirtualDisplayManager(url: URL(fileURLWithPath: path))
        }
        return CGVirtualDisplayManager()
    }
}
