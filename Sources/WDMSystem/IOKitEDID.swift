import Foundation
import IOKit
import IOKit.graphics
import CoreGraphics
import WDMCore

/// Reads the raw EDID bytes for a real display via `IODisplayCreateInfoDictionary`.
/// Pure public IOKit, no SPI. Returns nil for displays that don't expose EDID
/// (virtual displays, AirPlay receivers) — caller decides how to react.
enum IOKitEDID {
    static func read(_ id: CGDirectDisplayID) -> [UInt8]? {
        guard let service = framebufferService(for: id) else { return nil }
        defer { IOObjectRelease(service) }
        let info = IODisplayCreateInfoDictionary(
            service, IOOptionBits(kIODisplayOnlyPreferredName)
        ).takeRetainedValue() as? [String: Any]
        // EDID can show up under a couple of keys depending on macOS version
        // and connector type. Check both; either is the same 128-byte block.
        for key in [kIODisplayEDIDKey as String, "IODisplayEDIDOriginal"] {
            if let data = info?[key] as? Data {
                return Array(data)
            }
        }
        return nil
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
