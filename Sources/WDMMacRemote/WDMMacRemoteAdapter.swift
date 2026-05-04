import Foundation
import WDMRemoteControl

/// Adapts the in-process `RemoteRegistry` to the `RemoteControllable` protocol.
/// One adapter per `wdm-mac` process; passed to `RemoteControlServer`.
public final class WDMMacRemoteAdapter: RemoteControllable, @unchecked Sendable {
    public let registry: RemoteRegistry

    public init(registry: RemoteRegistry) {
        self.registry = registry
    }

    public func snapshot(interactive: Bool) throws -> SceneTree {
        // M1: every registered element is interactive — the filter is a no-op
        // until we register decorative nodes. Honest about scope.
        return registry.currentTree()
    }

    public func dispatch(_ action: RemoteAction) throws -> ActionResult {
        let version = registry.snapshotVersion()
        switch action {
        case .click(let ref):
            guard let hit = registry.entry(forRef: ref), let onClick = hit.entry.onClick else {
                return .staleRef(snapshotVersion: version)
            }
            onClick()
            return .ok(snapshotVersion: registry.snapshotVersion())
        default:
            return .unsupported(snapshotVersion: version, reason: "M1 dispatches click only")
        }
    }
}
