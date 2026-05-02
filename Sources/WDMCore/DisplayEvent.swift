import Foundation

public struct DisplayEvent: Equatable, Hashable, Sendable, Codable {
    public enum Kind: String, Equatable, Sendable, Codable {
        case added
        case removed
        case modeChanged
        case moved
        case mirrorChanged
        case mainChanged
    }

    public let timestamp: Date
    public let kind: Kind
    public let displayID: UInt32

    public init(timestamp: Date, kind: Kind, displayID: UInt32) {
        self.timestamp = timestamp
        self.kind = kind
        self.displayID = displayID
    }
}
