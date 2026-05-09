/// One row in an `ArrangementPlan` — the new origin for a display, plus
/// optional rotation. Used by bulk CLI/web arrangement ops
/// to apply many display moves in a single transaction.
public struct ArrangementEntry: Sendable, Codable, Equatable, Hashable {
    public let id: UInt32
    public let origin: Point
    public let rotationDegrees: Int?

    public init(id: UInt32, origin: Point, rotationDegrees: Int? = nil) {
        self.id = id
        self.origin = origin
        self.rotationDegrees = rotationDegrees
    }
}
