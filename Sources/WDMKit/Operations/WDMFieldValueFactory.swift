import WDMCore

extension WDMController {
    func fieldValue(of display: DisplayInfo, field: WDMDisplayField) throws -> WDMFieldValue {
        switch field {
        case .id:       return .uint(display.id)
        case .name:     return .text(display.name ?? "")
        case .mode:     return .mode(display.currentMode)
        case .origin:   return .point(display.origin)
        case .rotation: return .uint(UInt32(display.rotationDegrees))
        case .main:     return .bool(display.isMain)
        case .online:   return .bool(display.isOnline)
        case .mirror:   return .optionalUInt(display.mirrorSource)
        }
    }
}
