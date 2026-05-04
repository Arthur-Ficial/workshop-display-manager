import Foundation
import WDMKit

/// Dependencies for `wdm-mac`. Honours `WDM_TEST_FIXTURE` so the GUI in
/// headless mode reads from the same JSON fixture as the CLI's e2e tests.
/// Construct via `make(env:)`; never call `WDMController.init` directly from
/// the GUI — keep the SSOT.
public struct WDMMacAppDeps: @unchecked Sendable {
    public let controller: WDMController
    public let env: [String: String]

    public init(controller: WDMController, env: [String: String]) {
        self.controller = controller
        self.env = env
    }

    public static func make(env: [String: String] = ProcessInfo.processInfo.environment) throws -> WDMMacAppDeps {
        let provider = try DisplayProviderFactory.make(env: env)
        let profileStore = ProfileStore.resolve(env: env)
        return WDMMacAppDeps(
            controller: WDMController(provider: provider, profileStore: profileStore, env: env),
            env: env
        )
    }
}
