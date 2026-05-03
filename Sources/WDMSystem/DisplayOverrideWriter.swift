import Foundation
import WDMCore

/// Writes a macOS display-override plist that gives a monitor a custom
/// `DisplayProductName` system-wide. Same path BetterDisplay/SwitchResX
/// use. The override is per vendor+product ID — two identical monitors
/// share the same name (a documented limitation; we refuse on collision).
public enum DisplayOverrideWriter {
    public enum WriteError: Error, Equatable {
        case ambiguousIdenticalDisplays(vendorID: UInt32, productID: UInt32)
        case ioError(String)
    }

    public static func defaultOverridesDir(env: [String: String]) -> URL {
        if let p = env["WDM_OVERRIDES_DIR"], !p.isEmpty {
            return URL(fileURLWithPath: p)
        }
        return URL(fileURLWithPath: "/Library/Displays/Contents/Resources/Overrides")
    }

    /// Write `<dir>/DisplayVendorID-<vid>/DisplayProductID-<pid>` containing
    /// at minimum a `DisplayProductName` key. `vendorID` and `productID` come
    /// from the EDID parser; pass them as decoded `UInt16`/`UInt32`.
    public static func write(
        overridesDir: URL,
        vendorID: UInt32,
        productID: UInt16,
        productName: String
    ) throws {
        let vendorDir = overridesDir.appendingPathComponent(
            "DisplayVendorID-\(String(format: "%x", vendorID))"
        )
        try FileManager.default.createDirectory(
            at: vendorDir, withIntermediateDirectories: true
        )
        let plistFile = vendorDir.appendingPathComponent(
            "DisplayProductID-\(String(format: "%x", productID))"
        )
        let body = plistBody(productName: productName)
        do {
            try body.write(to: plistFile, atomically: true, encoding: .utf8)
        } catch {
            throw WriteError.ioError("\(error)")
        }
    }

    private static func plistBody(productName: String) -> String {
        // Escape any XML reserved chars in the user-provided name.
        let escaped = productName
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>DisplayProductName</key>
            <string>\(escaped)</string>
        </dict>
        </plist>
        """
    }

    /// EDID's manufacturer ID encoded back to its uint16 wire form.
    /// Inverse of `EDID.decodeManufacturer`.
    public static func vendorID(from manufacturerID: String) -> UInt32 {
        let chars = Array(manufacturerID)
        guard chars.count == 3 else { return 0 }
        let codes = chars.map { UInt32($0.asciiValue ?? 0) - 0x40 }
        return (codes[0] << 10) | (codes[1] << 5) | codes[2]
    }
}
