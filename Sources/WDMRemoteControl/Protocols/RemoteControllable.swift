import Foundation

/// Contract every AI-controllable frontend implements. The `RemoteControlServer`
/// takes any `RemoteControllable` and exposes the HTTP/SSE surface.
public protocol RemoteControllable: AnyObject, Sendable {
    /// Returns the current scene, optionally filtered to interactive elements only.
    func snapshot(interactive: Bool) throws -> SceneTree

    /// Dispatches an action against a node (resolved by `Ref`). Must run on the main
    /// actor in GUI implementations; the protocol stays sync to keep the wire shape
    /// simple. Honest about failure: returns a typed `ActionResult`.
    func dispatch(_ action: RemoteAction) throws -> ActionResult
}
