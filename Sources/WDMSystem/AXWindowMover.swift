import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

/// Real `WindowMover` backed by macOS Accessibility API. Finds the running
/// app whose name contains `pattern` (case-insensitive), grabs its frontmost
/// window via `AXUIElementCreateApplication`, and sets `kAXPositionAttribute`
/// + `kAXSizeAttribute` to ~80% of the destination display, centered.
///
/// **Permission:** requires Accessibility access in System Settings →
/// Privacy & Security → Accessibility. We probe with
/// `AXIsProcessTrustedWithOptions` and refuse honestly if missing.
///
/// **Caveats** (per research): sandboxed App Store apps and Electron apps
/// with AX off silently fail; fullscreen windows refuse moves; AX uses
/// top-left origin (already accounted for via `CGDisplayBounds`).
public final class AXWindowMover: WindowMover, @unchecked Sendable {
    public init() {}

    public func move(pattern: String, displayID: UInt32) throws {
        // Permission preflight. Use the literal key string — the symbol
        // `kAXTrustedCheckOptionPrompt` is var-qualified in the SDK and
        // Swift 6 strict concurrency rejects reading it from a non-isolated
        // context. The literal is contractually stable across macOS versions.
        let opts: [String: Bool] = ["AXTrustedCheckOptionPrompt": false]
        guard AXIsProcessTrustedWithOptions(opts as CFDictionary) else {
            throw ProviderError.configurationFailed(
                "move-window: Accessibility permission not granted for `wdm`. " +
                "Open System Settings → Privacy & Security → Accessibility, " +
                "enable `wdm`, then re-run."
            )
        }

        // Find a running app whose localized name contains the pattern.
        let lower = pattern.lowercased()
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            ($0.localizedName ?? "").lowercased().contains(lower)
        }) else {
            throw ProviderError.configurationFailed(
                "move-window: no running app matches '\(pattern)'"
            )
        }

        // Compute the target rect: ~80% of the display, centered. AX uses
        // top-left origin in display-bounds space, so use `CGDisplayBounds`
        // directly without the AppKit y-flip dance.
        let bounds = CGDisplayBounds(CGDirectDisplayID(displayID))
        let targetW = bounds.size.width * 0.8
        let targetH = bounds.size.height * 0.8
        let targetX = bounds.origin.x + (bounds.size.width  - targetW) / 2
        let targetY = bounds.origin.y + (bounds.size.height - targetH) / 2

        let appElem = AXUIElementCreateApplication(app.processIdentifier)
        var winRef: CFTypeRef?
        let getErr = AXUIElementCopyAttributeValue(
            appElem, kAXMainWindowAttribute as CFString, &winRef
        )
        guard getErr == .success, let winRef else {
            throw ProviderError.configurationFailed(
                "move-window: could not read main window of '\(app.localizedName ?? pattern)' (AXError \(getErr.rawValue))"
            )
        }
        // Force-cast to AXUIElement is safe — the AXAttributeName for
        // kAXMainWindow is contractually an AXUIElement.
        let win = winRef as! AXUIElement

        // Position then size. AXValueCreate wants a tagged pointer.
        var pos = CGPoint(x: targetX, y: targetY)
        var sz = CGSize(width: targetW, height: targetH)
        if let posVal = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, posVal)
        }
        if let szVal = AXValueCreate(.cgSize, &sz) {
            AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, szVal)
        }
        // Raise to front.
        AXUIElementPerformAction(win, kAXRaiseAction as CFString)
    }
}
