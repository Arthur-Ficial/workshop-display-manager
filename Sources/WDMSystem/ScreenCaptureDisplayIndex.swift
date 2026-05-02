import CoreGraphics

enum ScreenCaptureDisplayIndex {
    static func screencaptureIndex(displayID: CGDirectDisplayID) throws -> Int {
        try screencaptureIndex(displayID: displayID, activeDisplays: activeDisplays())
    }

    static func screencaptureIndex(
        displayID: CGDirectDisplayID,
        activeDisplays: [CGDirectDisplayID]
    ) throws -> Int {
        try zeroBasedPosition(displayID: displayID, activeDisplays: activeDisplays) + 1
    }

    static func zeroBasedPosition(
        displayID: CGDirectDisplayID,
        activeDisplays: [CGDirectDisplayID]
    ) throws -> Int {
        guard let index = activeDisplays.firstIndex(of: displayID) else {
            throw ProviderError.displayNotFound(UInt32(displayID))
        }
        return index
    }

    static func activeDisplays() throws -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        var err = CGGetActiveDisplayList(0, nil, &count)
        guard err == .success else {
            throw ProviderError.configurationFailed(
                "CGGetActiveDisplayList: \(err.rawValue)"
            )
        }
        var ids = Array<CGDirectDisplayID>(repeating: 0, count: Int(count))
        err = CGGetActiveDisplayList(count, &ids, &count)
        guard err == .success else {
            throw ProviderError.configurationFailed(
                "CGGetActiveDisplayList(2): \(err.rawValue)"
            )
        }
        return Array(ids.prefix(Int(count)))
    }
}
