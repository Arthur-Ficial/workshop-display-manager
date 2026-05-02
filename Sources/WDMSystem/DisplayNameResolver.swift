import Foundation
import AppKit
import CoreGraphics

/// Resolves a CGDirectDisplayID to a human-readable name (e.g. "Built-in Retina Display",
/// "DELL U2723QE"). Uses NSScreen.localizedName, which is public and reliable on
/// Apple Silicon and Intel.
public enum DisplayNameResolver {
    public static func name(for id: CGDirectDisplayID) -> String? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        for screen in NSScreen.screens {
            let num = (screen.deviceDescription[key] as? NSNumber)?.uint32Value
            if num == id {
                let n = screen.localizedName
                return n.isEmpty ? nil : n
            }
        }
        return nil
    }
}
