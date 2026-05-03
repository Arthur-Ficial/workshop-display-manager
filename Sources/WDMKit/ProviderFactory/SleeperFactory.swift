import Foundation
import WDMSystem

public enum SleeperFactory {
    /// `WDM_TEST_SLEEP_LOG` switches to the file-backed recording sleeper for
    /// hermetic tests; otherwise the real `IOPMSleepSystem`-backed sleeper.
    public static func make(env: [String: String]) -> Sleeper {
        if let path = env["WDM_TEST_SLEEP_LOG"], !path.isEmpty {
            return RecordingSleeper(url: URL(fileURLWithPath: path))
        }
        return IOKitSleeper()
    }
}
