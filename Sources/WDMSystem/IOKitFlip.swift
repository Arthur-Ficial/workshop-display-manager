import Foundation
import IOKit
import IOKit.graphics
import CoreGraphics
import WDMCore

/// Flips a display's framebuffer image across the X or Y axis (or both) via
/// `IOServiceRequestProbe` with `kIOFBSetTransform`. This is the same IOKit
/// pathway used by `IOKitRotation`; on Apple Silicon it requires the display
/// to expose an `IODisplayConnect` framebuffer (typically external monitors).
///
/// The IOKit "IOFBTransform" high word combines kIOScale* bit flags:
/// `kIOScaleInvertX = 0x20` (horizontal flip), `kIOScaleInvertY = 0x40`
/// (vertical flip), and rotation-derived flags from `kIOScaleRotateNN`.
/// We OR the flip bits into the rotation-encoded transform so the display
/// keeps its current rotation while picking up the requested flip.
///
/// `read` returns the last flip we successfully applied via `write` in this
/// process; macOS does not expose a public API for reading the framebuffer
/// transform back. This is documented and intentional — never a fake `.none`
/// when flip is actually in effect from a previous process.
enum IOKitFlip {

    private static let kIOFBSetTransform: UInt32 = 0x0000_0400

    private static let lock = NSLock()
    nonisolated(unsafe) private static var lastApplied: [CGDirectDisplayID: Flip] = [:]

    static func read(_ id: CGDirectDisplayID) -> Flip {
        lock.withLock { lastApplied[id] ?? .none }
    }

    static func write(_ id: CGDirectDisplayID, flip: Flip, rotationDegrees: Int) throws {
        guard let service = framebufferService(for: id) else {
            throw ProviderError.configurationFailed(
                "flip: no IOFramebuffer service for display \(id) — " +
                "Apple Silicon limitation; flip is only available on external " +
                "displays that expose an IODisplayConnect framebuffer"
            )
        }
        defer { IOObjectRelease(service) }

        let transform = encodeTransform(rotationDegrees: rotationDegrees, flip: flip)
        let option = (UInt32(transform) << 16) | kIOFBSetTransform
        let kr = IOServiceRequestProbe(service, option)
        guard kr == KERN_SUCCESS else {
            throw ProviderError.configurationFailed(
                "flip: IOServiceRequestProbe failed (kr=\(kr))"
            )
        }
        lock.withLock { lastApplied[id] = flip }
    }

    /// Pure encoder: combines a rotation in degrees and a flip into the
    /// IOFBTransform byte expected in the IOServiceRequestProbe high word.
    /// Rotation contribution: `kIOScaleRotateNN` (0x00 / 0x30 / 0x60 / 0x50).
    /// Flip contribution:    `kIOScaleInvertX (0x20)` and/or `kIOScaleInvertY (0x40)`.
    static func encodeTransform(rotationDegrees: Int, flip: Flip) -> UInt8 {
        let rotation: UInt8
        switch rotationDegrees {
        case 0:   rotation = 0x00                            // kIOScaleRotate0
        case 90:  rotation = 0x10 | 0x20                     // kIOScaleSwapAxes | kIOScaleInvertX = 0x30
        case 180: rotation = 0x20 | 0x40                     // kIOScaleInvertX  | kIOScaleInvertY = 0x60
        case 270: rotation = 0x10 | 0x40                     // kIOScaleSwapAxes | kIOScaleInvertY = 0x50
        default:  rotation = 0x00
        }
        var flipBits: UInt8 = 0
        if flip.invertsX { flipBits |= 0x20 }                 // kIOScaleInvertX
        if flip.invertsY { flipBits |= 0x40 }                 // kIOScaleInvertY
        // XOR so the flip toggles the corresponding rotation bit when the
        // rotation already encodes that axis (e.g. rotate-180 already inverts
        // both axes; flipping vertical on top should *cancel* the Y inversion).
        return rotation ^ flipBits
    }

    private static func framebufferService(for id: CGDirectDisplayID) -> io_service_t? {
        let vendor = CGDisplayVendorNumber(id)
        let model = CGDisplayModelNumber(id)
        let serial = CGDisplaySerialNumber(id)

        var iter: io_iterator_t = 0
        let matching = IOServiceMatching("IODisplayConnect")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iter) }

        var serv = IOIteratorNext(iter)
        while serv != 0 {
            let info = IODisplayCreateInfoDictionary(
                serv, IOOptionBits(kIODisplayOnlyPreferredName)
            ).takeRetainedValue() as? [String: Any]

            let v = info?[kDisplayVendorID] as? UInt32 ?? 0
            let m = info?[kDisplayProductID] as? UInt32 ?? 0
            let s = info?[kDisplaySerialNumber] as? UInt32 ?? 0
            let serialMatch = s == serial || s == 0 || serial == 0
            if v == vendor && m == model && serialMatch {
                return serv
            }
            IOObjectRelease(serv)
            serv = IOIteratorNext(iter)
        }
        return nil
    }
}
