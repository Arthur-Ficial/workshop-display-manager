import ApplicationServices
import CoreGraphics
import Foundation

enum PermissionProbe {
    static func screenRecordingMessage(context: String) -> String {
        "\(context): Screen Recording permission not granted for `wdm`. " +
        "Open System Settings → Privacy & Security → Screen Recording → " +
        "enable `wdm`, then re-run."
    }

    static func accessibilityMessage(context: String) -> String {
        "\(context): Accessibility permission not granted for `wdm`. " +
        "Open System Settings → Privacy & Security → Accessibility → " +
        "enable `wdm`, then re-run."
    }

    static func requireScreenRecording(context: String) throws {
        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            throw ProviderError.configurationFailed(
                screenRecordingMessage(context: context)
            )
        }
    }

    static func requireAccessibility(context: String) throws {
        guard hasAccessibility() else {
            throw ProviderError.configurationFailed(
                accessibilityMessage(context: context)
            )
        }
    }

    static func hasAccessibility() -> Bool {
        let opts: [String: Bool] = ["AXTrustedCheckOptionPrompt": false]
        return AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }
}
