import Foundation
import CoreGraphics
import WDMCore

public final class CGDisplayProvider: DisplayProvider, @unchecked Sendable {
    public init() {}

    public func snapshot() throws -> Snapshot {
        let ids = try Self.activeDisplayIDs()
        let mainID = CGMainDisplayID()
        let displays = try ids.map { try Self.makeInfo(id: $0, mainID: mainID) }
        return Snapshot(createdAt: Date(), displays: displays)
    }

    public func modes(for displayID: UInt32) throws -> [Mode] {
        guard try Self.activeDisplayIDs().contains(displayID) else {
            throw ProviderError.displayNotFound(displayID)
        }
        let opts: CFDictionary = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue!] as CFDictionary
        guard let raw = CGDisplayCopyAllDisplayModes(displayID, opts) as? [CGDisplayMode] else {
            return []
        }
        var seen = Set<Mode>()
        var modes: [Mode] = []
        for m in raw {
            let mode = Mode(width: m.width, height: m.height, refreshHz: m.refreshRate == 0 ? 60 : m.refreshRate)
            if seen.insert(mode).inserted { modes.append(mode) }
        }
        return modes
    }

    public func setMain(displayID: UInt32, options: ApplyOptions) throws -> ApplyResult {
        throw ProviderError.configurationFailed("setMain not yet wired through SafeTransaction")
    }

    public func setMode(displayID: UInt32, mode: Mode, options: ApplyOptions) throws -> ApplyResult {
        throw ProviderError.configurationFailed("setMode not yet wired through SafeTransaction")
    }

    public func mirror(source: UInt32, mirror target: UInt32, options: ApplyOptions) throws -> ApplyResult {
        throw ProviderError.configurationFailed("mirror not yet wired through SafeTransaction")
    }

    public func unmirror(displayID: UInt32, options: ApplyOptions) throws -> ApplyResult {
        throw ProviderError.configurationFailed("unmirror not yet wired through SafeTransaction")
    }

    public func move(displayID: UInt32, to origin: Point, options: ApplyOptions) throws -> ApplyResult {
        throw ProviderError.configurationFailed("move not yet wired through SafeTransaction")
    }

    public func rotate(displayID: UInt32, degrees: Int, options: ApplyOptions) throws -> ApplyResult {
        throw ProviderError.configurationFailed("rotate not yet wired through SafeTransaction")
    }

    // MARK: - CoreGraphics glue

    static func activeDisplayIDs() throws -> [UInt32] {
        var count: UInt32 = 0
        var err = CGGetActiveDisplayList(0, nil, &count)
        guard err == .success else { throw ProviderError.configurationFailed("CGGetActiveDisplayList: \(err.rawValue)") }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        err = CGGetActiveDisplayList(count, &ids, &count)
        guard err == .success else { throw ProviderError.configurationFailed("CGGetActiveDisplayList(2): \(err.rawValue)") }
        return ids
    }

    static func makeInfo(id: CGDirectDisplayID, mainID: CGDirectDisplayID) throws -> DisplayInfo {
        let bounds = CGDisplayBounds(id)
        let mirrorOf = CGDisplayMirrorsDisplay(id)
        let modeRef = CGDisplayCopyDisplayMode(id)
        let mode: Mode
        if let m = modeRef {
            mode = Mode(width: m.width, height: m.height, refreshHz: m.refreshRate == 0 ? 60 : m.refreshRate)
        } else {
            mode = Mode(width: Int(bounds.width), height: Int(bounds.height), refreshHz: 60)
        }
        let rotation = Int(CGDisplayRotation(id).rounded())
        return DisplayInfo(
            id: id,
            name: nil,
            isMain: id == mainID,
            isOnline: CGDisplayIsOnline(id) != 0,
            mirrorSource: mirrorOf == 0 ? nil : mirrorOf,
            currentMode: mode,
            origin: Point(x: Int(bounds.origin.x), y: Int(bounds.origin.y)),
            rotationDegrees: rotation
        )
    }
}
