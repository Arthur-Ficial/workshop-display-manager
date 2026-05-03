import Foundation

/// Read/write a raw VCP (Virtual Control Panel) code on a display via DDC/CI.
/// This is the protocol consumed by `wdm ddc`. Two impls:
///   - `IOAVDDCProvider` (real, IOAVServiceWriteI2C / IOI2CInterfaceOpen)
///   - `RecordingDDCProvider` (test, JSON-fixture map + log-file writes)
public protocol DDCProvider: Sendable {
    /// Read VCP `code` from `displayID`. Returns the current value (0…max,
    /// where max is monitor-defined; brightness/contrast are typically
    /// 0…100). Throws `ddcUnsupported` if the display doesn't speak DDC.
    func read(displayID: UInt32, vcp: UInt8) throws -> UInt16

    /// Write `value` to VCP `code` on `displayID`. Throws `ddcUnsupported`
    /// for non-DDC displays.
    func write(displayID: UInt32, vcp: UInt8, value: UInt16) throws
}

public enum DDCError: Error, Equatable, Sendable {
    case unsupported(UInt32)
    case ioFailure(String)
}

/// Standard MCCS VCP codes used by `wdm ddc`. Hand-rolled — no CCS
/// dependency. Monitor-specific codes are accessed via `wdm ddc get|set`.
public enum DDCCodes {
    public static let brightness: UInt8 = 0x10
    public static let contrast: UInt8 = 0x12
    public static let inputSource: UInt8 = 0x60
    public static let audioVolume: UInt8 = 0x62
    public static let audioMute: UInt8 = 0x8D
}

/// Canonical input-source aliases. Numeric codes per VESA MCCS where
/// they exist, plus the most common vendor-specific values for HDMI2 /
/// USB-C — these vary per monitor, so we expose the raw `wdm ddc set`
/// for cases where these don't match.
public enum DDCInputAlias {
    public static func code(for token: String) -> UInt16? {
        switch token.lowercased() {
        case "vga", "analog":         return 0x01
        case "dvi1":                  return 0x03
        case "dvi2":                  return 0x04
        case "dp", "displayport", "dp1": return 0x0F
        case "dp2":                   return 0x10
        case "hdmi", "hdmi1":         return 0x11
        case "hdmi2":                 return 0x12
        case "usbc", "usb-c":         return 0x1B
        default:                      return nil
        }
    }
}
