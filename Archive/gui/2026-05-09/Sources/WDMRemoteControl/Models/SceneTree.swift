import Foundation

/// Snapshot of the full visible scene at a point in time.
public struct SceneTree: Hashable, Sendable, Codable {
    public let version: Int
    public let nodes: [SceneNode]

    public init(version: Int, nodes: [SceneNode]) {
        self.version = version
        self.nodes = nodes
    }

    /// Flattens the tree (depth-first) and returns the node matching `ref`.
    public func node(for ref: Ref) -> SceneNode? {
        for n in nodes {
            if let hit = Self.find(ref: ref, in: n) { return hit }
        }
        return nil
    }

    private static func find(ref: Ref, in node: SceneNode) -> SceneNode? {
        if node.ref == ref { return node }
        for c in node.children {
            if let hit = find(ref: ref, in: c) { return hit }
        }
        return nil
    }
}
