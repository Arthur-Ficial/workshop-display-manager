import Foundation

/// Stable per-launch handle to a UI element. Format: `@e<n>` (e.g. `@e1`, `@e42`).
/// Refs are assigned by the adapter at registration time; they remain stable while
/// the underlying `remoteID` is alive. They are NOT stable across launches.
public struct Ref: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init?(_ raw: String) {
        guard raw.hasPrefix("@e"), Int(raw.dropFirst(2)) != nil else { return nil }
        self.rawValue = raw
    }

    public init(index: Int) {
        self.rawValue = "@e\(index)"
    }

    public var index: Int? { Int(rawValue.dropFirst(2)) }
}
