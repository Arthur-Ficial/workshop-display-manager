import Foundation
import IOKit
import IOKit.graphics
import CoreGraphics

/// Rotates a display via the framebuffer's `IOServiceRequestProbe` with
/// `kIOFBSetTransform` plus a rotation code. This is the same path used by
/// `fb-rotate`, `displayplacer`, and similar tools. Works on Intel and Apple
/// Silicon for displays that expose an `IODisplayConnect` framebuffer.
enum IOKitRotation {
    private static let kIOFBSetTransform: UInt32 = 0x0000_0400

    static func rotate(_ id: CGDirectDisplayID, degrees: Int) throws {
        guard let code = code(for: degrees) else {
            throw ProviderError.invalidRotation(degrees)
        }
        guard let service = framebufferService(for: id) else {
            throw ProviderError.configurationFailed(
                "rotate: no IOFramebuffer service for display \(id) — " +
                "Apple Silicon limitation; use System Settings → Displays → Rotation"
            )
        }
        defer { IOObjectRelease(service) }
        let option = (UInt32(code) << 16) | kIOFBSetTransform
        let kr = IOServiceRequestProbe(service, option)
        guard kr == KERN_SUCCESS else {
            throw ProviderError.configurationFailed(
                "rotate: IOServiceRequestProbe failed (kr=\(kr))"
            )
        }
    }

    static var isSupported: Bool {
        // Cheap probe: do we have any IODisplayConnect at all? If not, this is
        // Apple Silicon and rotate via IOServiceRequestProbe is unsupported.
        var iter: io_iterator_t = 0
        let matching = IOServiceMatching("IODisplayConnect")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
            return false
        }
        defer { IOObjectRelease(iter) }
        return IOIteratorNext(iter) != 0
    }

    private static func code(for degrees: Int) -> UInt8? {
        switch degrees {
        case 0:   return 0
        case 90:  return 1
        case 180: return 2
        case 270: return 3
        default:  return nil
        }
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
            let vendorMatch = v == vendor
            let modelMatch = m == model
            // Serial number is often 0 on both sides for displays without a serial.
            let serialMatch = s == serial || s == 0 || serial == 0

            if vendorMatch && modelMatch && serialMatch {
                return serv
            }
            IOObjectRelease(serv)
            serv = IOIteratorNext(iter)
        }
        return nil
    }
}
