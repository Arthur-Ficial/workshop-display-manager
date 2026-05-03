import WDMCore

public enum WDMFieldValue: Sendable, Equatable {
    case bool(Bool)
    case mode(Mode)
    case point(Point)
    case text(String)
    case uint(UInt32)
    case optionalUInt(UInt32?)
}
