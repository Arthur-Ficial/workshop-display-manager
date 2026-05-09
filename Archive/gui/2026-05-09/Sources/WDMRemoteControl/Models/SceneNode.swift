import Foundation

/// One element in the scene tree. Mirrors `agent-browser`'s a11y node shape.
public struct SceneNode: Hashable, Sendable, Codable {
    public let ref: Ref
    public let remoteID: String
    public let role: String
    public let label: String?
    public let value: String?
    public let bounds: NodeBounds?
    public let state: NodeState
    public let children: [SceneNode]

    public init(
        ref: Ref,
        remoteID: String,
        role: String,
        label: String? = nil,
        value: String? = nil,
        bounds: NodeBounds? = nil,
        state: NodeState = .init(),
        children: [SceneNode] = []
    ) {
        self.ref = ref
        self.remoteID = remoteID
        self.role = role
        self.label = label
        self.value = value
        self.bounds = bounds
        self.state = state
        self.children = children
    }
}

public struct NodeBounds: Hashable, Sendable, Codable {
    public let x: Double
    public let y: Double
    public let w: Double
    public let h: Double
    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }
}

public struct NodeState: Hashable, Sendable, Codable {
    public let selected: Bool
    public let enabled: Bool
    public let focused: Bool
    public init(selected: Bool = false, enabled: Bool = true, focused: Bool = false) {
        self.selected = selected
        self.enabled = enabled
        self.focused = focused
    }
}
