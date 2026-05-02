import Foundation

public struct DisplayInfo: Equatable, Hashable, Sendable, Codable {
    public let id: UInt32
    public let name: String?
    public let isMain: Bool
    public let isOnline: Bool
    public let mirrorSource: UInt32?
    public let currentMode: Mode
    public let origin: Point
    public let rotationDegrees: Int

    public init(
        id: UInt32,
        name: String?,
        isMain: Bool,
        isOnline: Bool,
        mirrorSource: UInt32?,
        currentMode: Mode,
        origin: Point,
        rotationDegrees: Int
    ) {
        self.id = id
        self.name = name
        self.isMain = isMain
        self.isOnline = isOnline
        self.mirrorSource = mirrorSource
        self.currentMode = currentMode
        self.origin = origin
        self.rotationDegrees = rotationDegrees
    }

    public var isMirrored: Bool { mirrorSource != nil }
}
