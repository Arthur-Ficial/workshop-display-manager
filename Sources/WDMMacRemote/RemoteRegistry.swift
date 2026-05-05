import Foundation
import WDMRemoteControl

/// Single source of truth for what the GUI is showing and which actions are
/// reachable. Views REGISTER their elements + handlers here; both the SwiftUI
/// renderer and the remote API READ from here. This is the DRY hinge: there
/// is exactly one description of every interactive element, used for both
/// drawing and remote dispatch.
public final class RemoteRegistry: @unchecked Sendable {
    public struct Entry: Sendable {
        public let role: String
        public let label: String?
        public var value: String?
        public var state: NodeState
        public var onClick: (@Sendable () -> Void)?

        public init(role: String, label: String? = nil, value: String? = nil,
                    state: NodeState = .init(), onClick: (@Sendable () -> Void)? = nil) {
            self.role = role
            self.label = label
            self.value = value
            self.state = state
            self.onClick = onClick
        }
    }

    private let lock = NSLock()
    private var byID: [String: Entry] = [:]
    private var order: [String] = []
    private var version: Int = 1

    public init() {}

    public func upsert(remoteID: String, entry: Entry) {
        lock.lock(); defer { lock.unlock() }
        if byID[remoteID] == nil { order.append(remoteID) }
        byID[remoteID] = entry
        version += 1
    }

    public func remove(remoteID: String) {
        lock.lock(); defer { lock.unlock() }
        byID.removeValue(forKey: remoteID)
        order.removeAll { $0 == remoteID }
        version += 1
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        byID.removeAll(); order.removeAll(); version += 1
    }

    /// Atomically replaces the entire registry contents in one transaction —
    /// one version bump regardless of how many entries change. Use this when
    /// re-rendering a whole region (e.g. the displays list); it eliminates
    /// the 1+N version-bump storm of reset()+upsert*N.
    public func replace(entries: [(String, Entry)]) {
        lock.lock(); defer { lock.unlock() }
        byID.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
        for (id, entry) in entries {
            order.append(id)
            byID[id] = entry
        }
        version += 1
    }

    public func currentTree() -> SceneTree {
        lock.lock(); defer { lock.unlock() }
        let nodes = order.enumerated().map { (idx, id) -> SceneNode in
            let e = byID[id]!
            return SceneNode(
                ref: Ref(index: idx + 1),
                remoteID: id,
                role: e.role,
                label: e.label,
                value: e.value,
                state: e.state
            )
        }
        return SceneTree(version: version, nodes: nodes)
    }

    public func entry(forRef ref: Ref) -> (id: String, entry: Entry)? {
        lock.lock(); defer { lock.unlock() }
        guard let idx = ref.index, idx >= 1, idx <= order.count else { return nil }
        let id = order[idx - 1]
        return (id, byID[id]!)
    }

    public func snapshotVersion() -> Int {
        lock.lock(); defer { lock.unlock() }
        return version
    }
}
