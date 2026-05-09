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
    public let virtualDisplayManagerFactory: @Sendable () -> VirtualDisplayManager
    public let pipFlipperFactory: @Sendable () -> PipFlipper
    public let recorderFactory: @Sendable () -> Recorder
    public let displayCapturerFactory: @Sendable () -> DisplayCapturer
    public let appearance: AppearanceStore
    public let env: [String: String]

    public init(controller: WDMController, overlayFlipper: OverlayFlipper,
                virtualDisplayManagerFactory: @escaping @Sendable () -> VirtualDisplayManager,
                pipFlipperFactory: @escaping @Sendable () -> PipFlipper,
                recorderFactory: @escaping @Sendable () -> Recorder,
                displayCapturerFactory: @escaping @Sendable () -> DisplayCapturer,
                appearance: AppearanceStore, env: [String: String]) {
        self.controller = controller
        self.overlayFlipper = overlayFlipper
        self.virtualDisplayManagerFactory = virtualDisplayManagerFactory
        self.pipFlipperFactory = pipFlipperFactory
        self.recorderFactory = recorderFactory
        self.displayCapturerFactory = displayCapturerFactory
        self.appearance = appearance
        self.env = env
    }

    public static func make(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> WDMMacAppDeps {
        let provider = try DisplayProviderFactory.make(env: env)
        let profileStore = ProfileStore.resolve(env: env)
        let environment = env
        return WDMMacAppDeps(
            controller: WDMController(provider: provider, profileStore: profileStore, env: env),
            overlayFlipper: makeOverlayFlipper(env: env),
            virtualDisplayManagerFactory: makeVirtualFactory(env: env),
            pipFlipperFactory: makePipFactory(env: env),
            recorderFactory: { RecorderFactory.make(env: environment) },
            displayCapturerFactory: { DisplayCapturerFactory.make(env: environment) },
            appearance: AppearanceStore(),
            env: env
        )
    }

    /// Honour WDM_TEST_PIP_LOG so hermetic tests get a recording PIP
    /// flipper; real runs get the AppKit ScreenCaptureKit-backed one.
    private static func makePipFactory(env: [String: String]) -> @Sendable () -> PipFlipper {
        let path = env["WDM_TEST_PIP_LOG"]
        return {
            if let p = path, !p.isEmpty {
                return RecordingPipFlipper(url: URL(fileURLWithPath: p))
            }
            return AppKitPipFlipper()
        }
    }

    /// Honour WDM_TEST_OVERLAY_LOG so hermetic tests get a recording
    /// flipper; real runs get the AppKit overlay window.
    private static func makeOverlayFlipper(env: [String: String]) -> OverlayFlipper {
        if let path = env["WDM_TEST_OVERLAY_LOG"], !path.isEmpty {
            return RecordingOverlayFlipper(
                url: URL(fileURLWithPath: path),
                throwMessage: env["WDM_TEST_OVERLAY_THROW"]
            )
        }
        return AppKitOverlayFlipper()
    }

    /// Honour WDM_TEST_VIRTUAL_LOG so hermetic tests get a recording
    /// manager; real runs get the CGVirtualDisplay-backed one. Each
    /// virtual-create call instantiates a fresh manager (single-shot).
    private static func makeVirtualFactory(env: [String: String]) -> @Sendable () -> VirtualDisplayManager {
        let path = env["WDM_TEST_VIRTUAL_LOG"]
        return {
            if let p = path, !p.isEmpty {
                return RecordingVirtualDisplayManager(url: URL(fileURLWithPath: p))
            }
            return CGVirtualDisplayManager()
        }
    }
}
