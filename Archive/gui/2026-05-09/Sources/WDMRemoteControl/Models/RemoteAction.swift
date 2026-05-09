import Foundation

/// A single user action that can be dispatched against a `RemoteControllable`.
/// Mirrors `agent-browser` action verbs. M1 ships `click` only; the rest are
/// declared so the wire format is forward-compatible.
public enum RemoteAction: Sendable, Equatable {
    case click(ref: Ref)
    case dblclick(ref: Ref)
    case hover(ref: Ref)
    case focus(ref: Ref)
    case scroll(ref: Ref?, direction: ScrollDirection, pixels: Int)
    case scrollIntoView(ref: Ref)
    case drag(from: Ref, to: DragTarget)
    case fill(ref: Ref, text: String)
    case type(ref: Ref, text: String)
    case press(key: String)
    case select(ref: Ref, value: String)
    case check(ref: Ref)
    case uncheck(ref: Ref)
    case closeWindow(name: String)
    case raiseWindow(name: String)
    case keystroke(key: String, modifiers: [String])
    case screenshot(window: String?)  // nil → main window
    case waitForRemoteID(remoteID: String, timeoutMs: Int)
    case invokeMenu(selector: String)
}

public enum ScrollDirection: String, Sendable, Codable {
    case up, down, left, right
}

public enum DragTarget: Sendable, Equatable {
    case ref(Ref)
    case point(x: Double, y: Double)
}
