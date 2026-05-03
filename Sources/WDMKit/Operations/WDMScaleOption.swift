import WDMCore

public struct WDMScaleOption: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let isCurrent: Bool

    public var label: String { "\(width)x\(height)" }

    public init(width: Int, height: Int, isCurrent: Bool) {
        self.width = width
        self.height = height
        self.isCurrent = isCurrent
    }
}
