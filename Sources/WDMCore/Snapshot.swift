import Foundation

public struct Snapshot: Equatable, Sendable, Codable {
    public let createdAt: Date
    public let displays: [DisplayInfo]

    public init(createdAt: Date, displays: [DisplayInfo]) {
        self.createdAt = createdAt
        self.displays = displays
    }

    public func display(id: UInt32) -> DisplayInfo? {
        displays.first { $0.id == id }
    }

    public var main: DisplayInfo? {
        displays.first { $0.isMain }
    }
}
