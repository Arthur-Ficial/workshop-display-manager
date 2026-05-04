import Foundation

/// Returned by `RemoteControllable.dispatch(_:)`. Honest about success or failure.
public struct ActionResult: Hashable, Sendable, Codable {
    public let ok: Bool
    public let snapshotVersion: Int
    public let error: String?
    public let reason: String?

    public init(ok: Bool, snapshotVersion: Int, error: String? = nil, reason: String? = nil) {
        self.ok = ok
        self.snapshotVersion = snapshotVersion
        self.error = error
        self.reason = reason
    }

    public static func ok(snapshotVersion: Int) -> ActionResult {
        .init(ok: true, snapshotVersion: snapshotVersion)
    }

    public static func staleRef(snapshotVersion: Int) -> ActionResult {
        .init(ok: false, snapshotVersion: snapshotVersion,
              error: "stale-ref", reason: "ref no longer exists in the current scene")
    }

    public static func unsupported(snapshotVersion: Int, reason: String) -> ActionResult {
        .init(ok: false, snapshotVersion: snapshotVersion,
              error: "unsupported", reason: reason)
    }
}
