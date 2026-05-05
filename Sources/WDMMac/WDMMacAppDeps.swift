import Foundation
import WDMKit
import WDMSystem

/// Dependencies for `wdm-mac`. Honours `WDM_TEST_FIXTURE` so the GUI in
/// headless mode reads from the same JSON fixture as the CLI's e2e tests.
/// Construct via `make(env:)`; never call `WDMController.init` directly from
/// the GUI — keep the SSOT.
@MainActor
public struct WDMMacAppDeps {
    public let controller: WDMController
    public let overlayFlipper: OverlayFlipper
    public let appearance: AppearanceStore
    public let env: [String: String]

    public init(controller: WDMController, overlayFlipper: OverlayFlipper,
                appearance: AppearanceStore, env: [String: String]) {
        self.controller = controller
        self.overlayFlipper = overlayFlipper
        self.appearance = appearance
        self.env = env
    }

    public static func make(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> WDMMacAppDeps {
        let provider = try DisplayProviderFactory.make(env: env)
        let profileStore = ProfileStore.resolve(env: env)
        // Honour WDM_TEST_FIXTURE for the flipper too — hermetic tests
        // get a recording flipper that writes one line per run; real
        // runs get the AppKit overlay window.
        let flipper: OverlayFlipper
        if let path = env["WDM_TEST_OVERLAY_LOG"], !path.isEmpty {
            flipper = RecordingOverlayFlipper(
                url: URL(fileURLWithPath: path),
                throwMessage: env["WDM_TEST_OVERLAY_THROW"]
            )
        } else {
            flipper = AppKitOverlayFlipper()
        }
        return WDMMacAppDeps(
            controller: WDMController(provider: provider, profileStore: profileStore, env: env),
            overlayFlipper: flipper,
            appearance: AppearanceStore(),
            env: env
        )
    }
}
