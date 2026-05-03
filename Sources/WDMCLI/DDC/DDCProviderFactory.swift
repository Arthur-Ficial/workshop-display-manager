import Foundation
import WDMSystem

/// Picks a `DDCProvider`. Tests set `WDM_TEST_DDC_LOG` (and reuse the
/// existing `WDM_TEST_FIXTURE` for reads) to swap in the recording impl.
public enum DDCProviderFactory {
    public static func make(env: [String: String]) -> DDCProvider {
        if let logPath = env["WDM_TEST_DDC_LOG"],
           let fxPath = env["WDM_TEST_FIXTURE"] {
            return RecordingDDCProvider(
                fixtureURL: URL(fileURLWithPath: fxPath),
                logURL: URL(fileURLWithPath: logPath)
            )
        }
        return IOAVDDCProvider()
    }
}
