import Foundation
import WDMMac
import WDMRemoteControl

/// Bundle of every long-lived object the wdm-mac runners need: deps, the
/// remote registry, the adapter that talks to it, the displays VM (with
/// reconfiguration observer running), and the runner that keeps the
/// registry in sync with the VM.
///
/// Both `HeadedRunner` and `HeadlessRunner` used to build all of these
/// inline — same five lines, same possibility of drifting. Constructing
/// once here is the SSOT for runtime wiring.
@MainActor
public struct MacRuntime {
    public let deps: WDMMacAppDeps
    public let registry: RemoteRegistry
    public let adapter: WDMMacRemoteAdapter
    public let vm: DisplaysListVM
    public let runner: WDMMacRemoteRunner

    public static func make() throws -> MacRuntime {
        let deps = try WDMMacAppDeps.make()
        let registry = RemoteRegistry()
        let adapter = WDMMacRemoteAdapter(registry: registry)
        let vm = DisplaysListVM(
            controller: deps.controller,
            overlayFlipper: deps.overlayFlipper,
            virtualDisplayManagerFactory: deps.virtualDisplayManagerFactory
        )
        vm.reload()
        vm.reloadProfiles()
        vm.startObservingReconfigurations()
        vm.startPollingProfiles()
        let runner = WDMMacRemoteRunner(registry: registry, vm: vm)
        return MacRuntime(deps: deps, registry: registry,
                          adapter: adapter, vm: vm, runner: runner)
    }

    private init(deps: WDMMacAppDeps, registry: RemoteRegistry,
                 adapter: WDMMacRemoteAdapter,
                 vm: DisplaysListVM, runner: WDMMacRemoteRunner) {
        self.deps = deps
        self.registry = registry
        self.adapter = adapter
        self.vm = vm
        self.runner = runner
    }
}
