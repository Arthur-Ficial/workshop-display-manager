import Foundation
import WDMSystem

public enum DisplayProviderFactory {
    /// Build the provider that the CLI should use given the environment.
    /// `WDM_TEST_FIXTURE` switches to the hermetic fixture provider; otherwise CGDisplayProvider.
    public static func make(env: [String: String]) throws -> DisplayProvider {
        if let path = env["WDM_TEST_FIXTURE"], !path.isEmpty {
            let failOnRotate = env["WDM_FIXTURE_FAIL_ROTATE"] == "1"
            return try FixtureDisplayProvider(
                fixtureURL: URL(fileURLWithPath: path),
                failOnRotate: failOnRotate
            )
        }
        return CGDisplayProvider()
    }
}
