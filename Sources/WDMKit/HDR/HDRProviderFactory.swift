import Foundation
import WDMSystem

public enum HDRProviderFactory {
    public static func make(env: [String: String]) -> HDRProvider {
        if let log = env["WDM_TEST_HDR_LOG"], let fx = env["WDM_TEST_FIXTURE"] {
            return RecordingHDRProvider(
                fixtureURL: URL(fileURLWithPath: fx),
                logURL: URL(fileURLWithPath: log)
            )
        }
        return CoreDisplayHDRProvider()
    }
}
