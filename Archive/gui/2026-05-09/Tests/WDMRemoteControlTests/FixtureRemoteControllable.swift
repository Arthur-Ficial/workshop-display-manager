import Foundation
@testable import WDMRemoteControl

/// In-memory `RemoteControllable` for unit tests. Holds a hand-built scene
/// and a click count per ref.
final class FixtureRemoteControllable: RemoteControllable, @unchecked Sendable {
    private var version = 1
    private var nodes: [SceneNode]
    private(set) var clicks: [Ref: Int] = [:]
    private let lock = NSLock()

    init(nodes: [SceneNode]) {
        self.nodes = nodes
    }

    func snapshot(interactive: Bool) throws -> SceneTree {
        lock.lock(); defer { lock.unlock() }
        return SceneTree(version: version, nodes: nodes)
    }

    func dispatch(_ action: RemoteAction) throws -> ActionResult {
        lock.lock(); defer { lock.unlock() }
        switch action {
        case .click(let ref):
            guard nodes.contains(where: { $0.ref == ref }) else {
                return .staleRef(snapshotVersion: version)
            }
            clicks[ref, default: 0] += 1
            version += 1
            return .ok(snapshotVersion: version)
        default:
            return .unsupported(snapshotVersion: version, reason: "fixture only does click")
        }
    }
}
