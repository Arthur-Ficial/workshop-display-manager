import Foundation
import CoreGraphics

/// Production `HDRProvider` using CoreDisplay private SPI. Same risk
/// tier wdm already accepts (CGVirtualDisplay, DisplayServices). All
/// symbols resolved via dlsym so the build needs no private headers;
/// missing symbols → `unsupported`, never a fake success.
public final class CoreDisplayHDRProvider: HDRProvider, @unchecked Sendable {
    public init() {}

    private static func coreDisplayHandle() -> UnsafeMutableRawPointer? {
        dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY)
            ?? dlopen(nil, RTLD_LAZY)
    }

    public func isHDREnabled(displayID: UInt32) throws -> Bool? {
        guard let handle = Self.coreDisplayHandle(),
              let sym = dlsym(handle, "CoreDisplay_Display_IsHDRModeEnabled") else {
            return nil
        }
        typealias Fn = @convention(c) (CGDirectDisplayID) -> Bool
        let isEnabled = unsafeBitCast(sym, to: Fn.self)
        // Probe support: try the "supports HDR" symbol if available.
        if let supSym = dlsym(handle, "CoreDisplay_Display_IsHDRModeSupported") {
            typealias SupFn = @convention(c) (CGDirectDisplayID) -> Bool
            let supports = unsafeBitCast(supSym, to: SupFn.self)
            if !supports(displayID) { return nil }
        }
        return isEnabled(displayID)
    }

    public func setHDR(displayID: UInt32, enabled: Bool) throws {
        guard let handle = Self.coreDisplayHandle(),
              let sym = dlsym(handle, "CoreDisplay_Display_SetHDRModeEnabled") else {
            throw HDRError.unsupported(displayID)
        }
        if let supSym = dlsym(handle, "CoreDisplay_Display_IsHDRModeSupported") {
            typealias SupFn = @convention(c) (CGDirectDisplayID) -> Bool
            let supports = unsafeBitCast(supSym, to: SupFn.self)
            if !supports(displayID) { throw HDRError.unsupported(displayID) }
        }
        typealias Fn = @convention(c) (CGDirectDisplayID, Bool) -> Void
        let set = unsafeBitCast(sym, to: Fn.self)
        set(displayID, enabled)
    }
}
