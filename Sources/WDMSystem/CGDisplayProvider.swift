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
        try assertExists(displayID)
        return Self.cgModes(for: displayID).map(Self.mode(from:))
            .reduce(into: [Mode]()) { acc, m in if !acc.contains(m) { acc.append(m) } }
    }

    public func setMain(displayID: UInt32, options: ApplyOptions) throws -> ApplyResult {
        try assertExists(displayID)
        if CGMainDisplayID() == displayID { return .noChange }
        let snap = try snapshot()
        guard let target = snap.display(id: displayID) else {
            throw ProviderError.displayNotFound(displayID)
        }
        // Translate every display so the new main lands at (0,0).
        // Relative positions of secondary displays are preserved.
        let dx = -target.origin.x
        let dy = -target.origin.y
        return try applyConfig { config in
            for d in snap.displays {
                let newX = Int32(d.origin.x + dx)
                let newY = Int32(d.origin.y + dy)
                let err = CGConfigureDisplayOrigin(config, d.id, newX, newY)
                try Self.check(err, "setMain.shift(\(d.id))")
            }
        }
    }

    public func setMode(displayID: UInt32, mode: Mode, options: ApplyOptions) throws -> ApplyResult {
        try assertExists(displayID)
        let current = try Self.makeInfo(id: displayID, mainID: CGMainDisplayID()).currentMode
        if current == mode { return .noChange }
        guard let cgMode = Self.cgMode(for: displayID, matching: mode) else {
            throw ProviderError.modeNotSupported
        }
        return try applyConfig { config in
            let err = CGConfigureDisplayWithDisplayMode(config, displayID, cgMode, nil)
            try Self.check(err, "setMode")
        }
    }

    public func mirror(source: UInt32, mirror target: UInt32, options: ApplyOptions) throws -> ApplyResult {
        try assertExists(source)
        try assertExists(target)
        if CGDisplayMirrorsDisplay(target) == source { return .noChange }
        return try applyConfig { config in
            let err = CGConfigureDisplayMirrorOfDisplay(config, target, source)
            try Self.check(err, "mirror")
        }
    }

    public func unmirror(displayID: UInt32, options: ApplyOptions) throws -> ApplyResult {
        try assertExists(displayID)
        if CGDisplayMirrorsDisplay(displayID) == 0 { return .noChange }
        return try applyConfig { config in
            let err = CGConfigureDisplayMirrorOfDisplay(config, displayID, kCGNullDirectDisplay)
            try Self.check(err, "unmirror")
        }
    }

    public func move(displayID: UInt32, to origin: Point, options: ApplyOptions) throws -> ApplyResult {
        try assertExists(displayID)
        let bounds = CGDisplayBounds(displayID)
        if Int(bounds.origin.x) == origin.x, Int(bounds.origin.y) == origin.y {
            return .noChange
        }
        return try applyConfig { config in
            let err = CGConfigureDisplayOrigin(config, displayID, Int32(origin.x), Int32(origin.y))
            try Self.check(err, "move")
        }
    }

    public func rotate(displayID: UInt32, degrees: Int, options: ApplyOptions) throws -> ApplyResult {
        guard [0, 90, 180, 270].contains(degrees) else { throw ProviderError.invalidRotation(degrees) }
        try assertExists(displayID)
        let current = Int(CGDisplayRotation(displayID).rounded())
        if current == degrees { return .noChange }
        // Rotation requires the private IOServiceRequestProbe + kIOFBSetTransform path.
        // Implementing it correctly across hardware vendors is out of scope for this
        // version; the user can use System Settings → Displays → Rotate.
        throw ProviderError.configurationFailed(
            "rotate requires private IOKit APIs not yet wired; use System Settings"
        )
    }

    // MARK: - apply with auto-revert on CG-side failure

    private func applyConfig(_ block: (CGDisplayConfigRef) throws -> Void) throws -> ApplyResult {
        var config: CGDisplayConfigRef?
        let beginErr = CGBeginDisplayConfiguration(&config)
        guard beginErr == .success, let cfg = config else {
            throw ProviderError.configurationFailed("CGBeginDisplayConfiguration: \(beginErr.rawValue)")
        }
        do {
            try block(cfg)
        } catch {
            CGCancelDisplayConfiguration(cfg)
            throw error
        }
        let completeErr = CGCompleteDisplayConfiguration(cfg, .permanently)
        if completeErr != .success {
            // CG itself failed during commit — restore last permanent config and surface error.
            CGRestorePermanentDisplayConfiguration()
            throw ProviderError.configurationFailed(
                "CGCompleteDisplayConfiguration: \(completeErr.rawValue) (auto-restored)"
            )
        }
        return .applied
    }

    private func assertExists(_ id: CGDirectDisplayID) throws {
        guard try Self.activeDisplayIDs().contains(id) else {
            throw ProviderError.displayNotFound(id)
        }
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
        let mode: Mode
        if let m = CGDisplayCopyDisplayMode(id) {
            mode = Self.mode(from: m)
        } else {
            mode = Mode(width: Int(bounds.width), height: Int(bounds.height), refreshHz: 60)
        }
        return DisplayInfo(
            id: id,
            name: nil,
            isMain: id == mainID,
            isOnline: CGDisplayIsOnline(id) != 0,
            mirrorSource: mirrorOf == 0 ? nil : mirrorOf,
            currentMode: mode,
            origin: Point(x: Int(bounds.origin.x), y: Int(bounds.origin.y)),
            rotationDegrees: Int(CGDisplayRotation(id).rounded())
        )
    }

    static func mode(from cg: CGDisplayMode) -> Mode {
        Mode(
            width: cg.width,
            height: cg.height,
            refreshHz: cg.refreshRate == 0 ? 60 : cg.refreshRate
        )
    }

    static func cgModes(for id: CGDirectDisplayID) -> [CGDisplayMode] {
        let opts: CFDictionary = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue!] as CFDictionary
        return (CGDisplayCopyAllDisplayModes(id, opts) as? [CGDisplayMode]) ?? []
    }

    static func cgMode(for id: CGDirectDisplayID, matching mode: Mode) -> CGDisplayMode? {
        cgModes(for: id).first { cg in
            cg.width == mode.width && cg.height == mode.height &&
                (cg.refreshRate == 0 ? 60 : cg.refreshRate) == mode.refreshHz
        }
    }

    static func check(_ err: CGError, _ what: String) throws {
        guard err == .success else {
            throw ProviderError.configurationFailed("\(what): CGError \(err.rawValue)")
        }
    }
}
